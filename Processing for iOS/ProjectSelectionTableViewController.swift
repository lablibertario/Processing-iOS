//
//  ProjectSelectionTableViewController.swift
//  Processing for iOS
//
//  Created by Frederik Riedel on 5/15/18.
//  Copyright © 2018 Frederik Riedel. All rights reserved.
//

import UIKit

class ProjectSelectionTableViewController: UITableViewController,
                                        UIViewControllerPreviewingDelegate,
                                        UIAlertViewDelegate {

    @IBOutlet weak var projectsCountLabel: UIBarButtonItem!

    var projects: [PDESketch]?
    var filteredProjects: [PDESketch]?
    let searchController = UISearchController(searchResultsController: nil)

    override func viewDidLoad() {
        super.viewDidLoad()

        searchController.searchResultsUpdater = self
        searchController.searchBar.placeholder = "Search Projects"
        if #available(iOS 9.1, *) {
            searchController.obscuresBackgroundDuringPresentation = false
        }
        searchController.searchBar.keyboardAppearance = .dark
        searchController.searchBar.tintColor = UIColor.white
        searchController.searchBar.barStyle = .black

        if #available(iOS 11.0, *) {
            navigationItem.searchController = searchController
        }
        definesPresentationContext = true

        SketchController.loadSketches { (projects) in
            self.projects = projects
            self.tableView.reloadData()
        }

        refreshProjectsCountLabel()
        projectsCountLabel.isEnabled = false
        projectsCountLabel.setTitleTextAttributes(
            [NSAttributedStringKey.font: UIFont.systemFont(ofSize: 13)],
            for: .disabled
        )
        registerForPreviewing(with: self, sourceView: tableView)
    }

    func refreshProjectsCountLabel() {
        if let numberOfProjects = projects?.count {
            projectsCountLabel.title = "\(numberOfProjects) Projects"
        } else {
            projectsCountLabel.title = "0 Projects"
        }
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        if isFiltering() {
            if let count = filteredProjects?.count {
                return count
            }
            return 0
        }

        if let count = projects?.count {
            return count
        }
        return 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "project-cell", for: indexPath)
            as? ProjectTableViewCell else {
                fatalError("Misconfigured cell type!")
        }

        if isFiltering() {
            if let project = filteredProjects?[indexPath.row] {
                cell.projectNameLabel.text = project.sketchName
            }
            return cell
        }

        if let project = projects?[indexPath.row] {
            cell.projectNameLabel.text = project.sketchName

            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .medium

            cell.creationDateLabel.text = "Created: \(dateFormatter.string(from: project.creationDate))"
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 66
    }

    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if isFiltering() {
            return false
        }
        return true
    }

    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle,
                            forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            if let project = projects?[indexPath.row] {

                let alertController = UIAlertController(
                    title: "Delete Project",
                    message: "Are you sure that you want to delete the project \"\(project.sketchName!)\"? " +
                        "This cannot be undone.",
                    preferredStyle: .alert)

                let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { (_) in
                    SketchController.deleteSketch(withName: project.sketchName)

                    SketchController.loadSketches { (projects) in
                        self.projects = projects
                        self.tableView.deleteRows(at: [indexPath], with: .automatic)
                        self.refreshProjectsCountLabel()
                    }
                }
                alertController.addAction(deleteAction)

                let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (_) in

                }
                alertController.addAction(cancelAction)

                present(alertController, animated: true)
            }
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        var currentProjects = projects
        if isFiltering() {
            currentProjects = filteredProjects
        }

        if let project = currentProjects?[indexPath.row] {
            let editor = EditorTabViewController(withProject: project)
//            let editor = PDEEditorViewController(pdeSketch: project)!
            navigationController?.pushViewController(editor, animated: true)
        }
    }

    @IBAction func about(_ sender: Any) {
        let aboutVC = AboutViewController()
        let aboutNavigationController = ProcessingNavigationViewController(rootViewController: aboutVC)
        aboutNavigationController.modalTransitionStyle = .coverVertical
        aboutNavigationController.modalPresentationStyle = .formSheet

        self.navigationController?.present(aboutNavigationController, animated: true, completion: nil)
    }

    @IBAction func createNewProject(_ sender: Any) {
        showCreateAlert(title: "New Processing Project", name: "")
    }

    func showCreateAlert(title: String, name: String) {
        let alertController = UIAlertController(title: title, message: "", preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { (_) in
                alertController.dismiss(animated: true, completion: nil)
        }))

        alertController.addAction(createAlertAction(alertController: alertController))

        alertController.addTextField(configurationHandler: { (textField) -> Void in
            textField.textAlignment = .left
            textField.text = name
        })

        self.present(alertController, animated: true, completion: nil)
    }

    func createAlertAction(alertController: UIAlertController) -> UIAlertAction {
        return UIAlertAction(title: "Create", style: .default, handler: { (_) in
            if let fileName = alertController.textFields?[0].text {
                let letters = NSMutableCharacterSet.letters as? NSMutableCharacterSet
                letters?.addCharacters(in: "-_1234567890")

                var message = ""
                var suggestedName = fileName
                if fileName == "" {
                    message = "Name should be at least one character"
                } else if self.nameAlreadyExists(name: fileName) {
                    message = "File with name '\(fileName)' already exists. " +
                    "Please choose another name or delete the exiting one first."
                } else if fileName.contains(" ") {
                    message = "File name should not contain spaces."
                    suggestedName = fileName.replacingOccurrences(of: " ", with: "_")
                } else if !(letters?.isSuperset(of: CharacterSet.init(charactersIn: fileName)))! {
                    message = "File name should contain no fancy symbols."
                } else {
                    // filename is correct
                    let newProject = PDESketch(sketchName: fileName)
                    SketchController.save(newProject)

                    let newFile = PDEFile(fileName: fileName, partOf: newProject)
                    newFile?.saveCode(
                        "void setup() {\n   size(screen.width, screen.height);\n}\n\n" +
                        "void draw() {\n   background(0,0,255);\n}"
                    )

                    SketchController.loadSketches { (projects) in
                        self.projects = projects
                        self.tableView.reloadData()
                        self.refreshProjectsCountLabel()

                        var index: Int?
                        for (ind, project) in projects!.enumerated()
                            where project.sketchName == newProject?.sketchName {
                                index = ind
                                break
                        }

                        if let index = index {
                            self.tableView.selectRow(
                                at: IndexPath(row: index, section: 0),
                                animated: true,
                                scrollPosition: .middle
                            )
                        }
                    }
                    return
                }

                self.showCreateAlert(title: message, name: suggestedName)
            }
        })
    }

    private func nameAlreadyExists(name: String) -> Bool {
        for project in projects! where project.sketchName == name {
            return true
        }
        return false
    }

    func previewingContext(_ previewingContext: UIViewControllerPreviewing,
                           viewControllerForLocation location: CGPoint) -> UIViewController? {
        if let indexPath = tableView.indexPathForRow(at: location) {
            let cell = tableView.cellForRow(at: indexPath)
            previewingContext.sourceRect = (cell?.frame)!

            let project: PDESketch
            if isFiltering() {
                project = filteredProjects![indexPath.row]
            } else {
                project = projects![indexPath.row]
            }
            let editor = EditorTabViewController(withProject: project)
            return editor
        }

        return nil
    }

    func previewingContext(_ previewingContext: UIViewControllerPreviewing,
                           commit viewControllerToCommit: UIViewController) {
        navigationController?.pushViewController(viewControllerToCommit, animated: false)

    }

    private func searchBarIsEmpty() -> Bool {
        // Returns true if the text is empty or nil
        return searchController.searchBar.text?.isEmpty ?? true
    }

    func filterContentForSearchText(_ searchText: String, scope: String = "All") {
        filteredProjects = projects?.filter({ (project) -> Bool in
            return project.sketchName!.lowercased().contains(searchText.lowercased())
        })

        tableView.reloadData()
    }

    private func isFiltering() -> Bool {
        return searchController.isActive && !searchBarIsEmpty()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}

extension ProjectSelectionTableViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        filterContentForSearchText(searchController.searchBar.text!)
    }
}
