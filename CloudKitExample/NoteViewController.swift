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
}

extension NoteViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        note.content = textView.text
        CloudNoteHelper.shared.syncToCloud(note: note)
    }
}
