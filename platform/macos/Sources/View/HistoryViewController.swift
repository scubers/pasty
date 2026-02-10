// Pasty2 - Copyright (c) 2026. MIT License.

import Cocoa
import PastyCore

final class HistoryViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    private var items: [HistoryItemViewModel] = []

    private let refreshButton = NSButton(title: "Refresh", target: nil, action: nil)
    private let deleteButton = NSButton(title: "Delete Selected", target: nil, action: nil)
    private let tableView = NSTableView()

    override func loadView() {
        view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false

        refreshButton.target = self
        refreshButton.action = #selector(refreshTapped)

        deleteButton.target = self
        deleteButton.action = #selector(deleteTapped)

        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true

        let titleColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("title"))
        titleColumn.title = "Item"
        titleColumn.width = 420
        let subtitleColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("subtitle"))
        subtitleColumn.title = "Details"
        subtitleColumn.width = 520

        tableView.addTableColumn(titleColumn)
        tableView.addTableColumn(subtitleColumn)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = NSTableHeaderView()
        scrollView.documentView = tableView

        let controls = NSStackView(views: [refreshButton, deleteButton])
        controls.orientation = .horizontal
        controls.spacing = 12
        controls.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(controls)
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            controls.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            controls.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),

            scrollView.topAnchor.constraint(equalTo: controls.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
        ])
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        refreshList()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        items.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0, row < items.count else {
            return nil
        }

        let item = items[row]
        let textField = NSTextField(labelWithString: tableColumn?.identifier.rawValue == "subtitle" ? item.subtitleText : item.titleText)
        textField.lineBreakMode = .byTruncatingTail
        return textField
    }

    @objc private func refreshTapped() {
        refreshList()
    }

    @objc private func deleteTapped() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < items.count else {
            return
        }

        let selected = items[selectedRow]
        selected.id.withCString { pointer in
            _ = pasty_history_delete(pointer)
        }
        refreshList()
    }

    private func refreshList() {
        guard let jsonCString = pasty_history_list_json(200) else {
            items = []
            tableView.reloadData()
            return
        }
        let jsonString = String(cString: jsonCString)
        let data = Data(jsonString.utf8)

        do {
            items = try JSONDecoder().decode([HistoryItemViewModel].self, from: data)
        } catch {
            LoggerService.error("[history-ui] failed to decode list: \(error)")
            items = []
        }

        tableView.reloadData()
    }
}
