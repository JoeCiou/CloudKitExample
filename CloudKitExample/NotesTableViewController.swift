//
//  NotesTableViewController.swift
//  CloudKitExample
//
//  Created by Joe Ciou on 2019/3/27.
//  Copyright © 2019 Joe Ciou. All rights reserved.
//

import UIKit

class NotesTableViewController: UITableViewController {

    var notes: [Note] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()

    }

    @IBAction func handleAddClick(_ sender: Any) {
        let alert = UIAlertController(title: "New Note", message: nil, preferredStyle: .alert)
        alert.addTextField { (textField) in
            textField.placeholder = "Title"
        }
        let createAction = UIAlertAction(title: "Create", style: .default) { (_) in
            let title = alert.textFields!.last!.text!
            guard title.count != 0 else {
                return
            }
            
            self.notes.append(Note(title: title))
            self.tableView.reloadData()
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alert.addAction(createAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true, completion: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "NoteSegue" {
            let vc = segue.destination as! NoteViewController
            vc.note = sender as? Note
        }
    }
    
    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return notes.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "NoteCell", for: indexPath)
        cell.textLabel?.text = notes[indexPath.row].title
        
        return cell
    }
    
    // MARK: - Table view delegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        performSegue(withIdentifier: "NoteSegue", sender: notes[indexPath.row])
    }
}
