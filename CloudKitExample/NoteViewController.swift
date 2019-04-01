//
//  NoteViewController.swift
//  CloudKitExample
//
//  Created by Joe Ciou on 2019/3/27.
//  Copyright © 2019 Joe Ciou. All rights reserved.
//

import UIKit

class NoteViewController: UIViewController {

    weak var note: Note!
    @IBOutlet weak var contentTextView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = note.title
        contentTextView.text = note.content
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleNotesChanged),
                                               name: NoteStorage.NoteChangedNotificationName,
                                               object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        contentTextView.becomeFirstResponder()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    @IBAction func handleTrashClick(_ sender: Any) {
        noteStorage.deleteNote(&note)
    }
    
    @objc func handleNotesChanged() {
        DispatchQueue.main.async {
            if let note = self.note {
                self.navigationItem.title = note.title
                self.contentTextView.text = note.content
            } else {
                let alert = UIAlertController(title: "Warning", message: "This note has been deleted", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Okay", style: .default, handler: { (_) in
                    self.navigationController?.popViewController(animated: true)
                }))
                self.present(alert, animated: true, completion: nil)
            }
        }
    }
}

extension NoteViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        noteStorage.updateNote(note, content: textView.text)
    }
}
