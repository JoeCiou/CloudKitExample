//
//  NoteViewController.swift
//  CloudKitExample
//
//  Created by Joe Ciou on 2019/3/27.
//  Copyright © 2019 Joe Ciou. All rights reserved.
//

import UIKit

class NoteViewController: UIViewController {

    var note: Note!
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
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc func handleNotesChanged() {
        DispatchQueue.main.async {
            self.navigationItem.title = self.note.title
            self.contentTextView.text = self.note.content
        }
    }
}

extension NoteViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        noteStorage.updateNote(note, content: textView.text)
    }
}
