//
//  ScheduleSearchViewController.swift
//  ToDoList
//
//  Created by 최광현 on 2021/04/12.
//

import UIKit
import SnapKit
import RxCocoa
import RxSwift
import RxDataSources
import CoreData


class ScheduleSearchViewController: UIViewController {
    
    typealias Schedules = [Schedule]
    typealias ScheduleSectionModel = SectionModel<String, Schedule>
    typealias ScheduleDataSource = RxTableViewSectionedReloadDataSource<ScheduleSectionModel>
    
    var disposeBag = DisposeBag()
    
    let searchTextField: UISearchTextField = {
        let textField = UISearchTextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        return textField
    }()
    
    let searchResultTableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.separatorStyle = .none
        tableView.register(ScheduleCell.self, forCellReuseIdentifier: ScheduleCell.cellId)
        return tableView
    }()
    
    let viewModel = ScheduleSearchViewModel()
    
    let context = PersistantManager.shared.context
    var searchedSchedules = Schedules()

    private let dateFormatter = DateFormatter()
    
    private var scheduleDatasource: ScheduleDataSource {
        let configureCell: (TableViewSectionedDataSource<ScheduleSectionModel>, UITableView, IndexPath, Schedule) -> UITableViewCell = { (source, tableView, indexPath, schedule) in
            guard let cell = tableView.dequeueReusableCell(withIdentifier: ScheduleCell.cellId, for: indexPath) as? ScheduleCell else { return UITableViewCell() }
            cell.schedule = schedule
            return cell
        }
        let dataSource = ScheduleDataSource(configureCell: configureCell)
        dataSource.titleForHeaderInSection = {dataSource, index in
            return dataSource.sectionModels[index].model
        }
        return dataSource
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        searchTextField.delegate = self
        searchResultTableView.delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setSubviews()
        bindUI()
    }
    
    // MARK: 키보드 숨기기
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
    
    func setSubviews() {
        view.addSubview(searchTextField)
        searchTextField.snp.makeConstraints{
            $0.top.equalTo(view.safeAreaLayoutGuide)
            $0.leading.trailing.equalTo(view.safeAreaLayoutGuide).inset(10)
            $0.height.equalTo(50)
        }
        
        view.addSubview(searchResultTableView)
        searchResultTableView.snp.makeConstraints {
            $0.top.equalTo(searchTextField.snp.bottom).offset(5)
            $0.leading.trailing.equalTo(view.safeAreaLayoutGuide)
            $0.bottom.equalTo(view.safeAreaLayoutGuide)
        }
    }
    
    func bindUI() {
        searchTextField.rx
            .text
            .orEmpty
            .distinctUntilChanged()
            .asDriver(onErrorJustReturn: "")
            .drive(viewModel.searchTextFieldRelay)
            .disposed(by: disposeBag)
        
        viewModel.resultSchedulesRelay
            .bind(to: searchResultTableView.rx.items(dataSource: scheduleDatasource))
            .disposed(by: disposeBag)
    }
}

extension ScheduleSearchViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("cell touched")
        guard let cell = searchResultTableView.cellForRow(at: indexPath) as? ScheduleCell else {return}
        cell.contentsTextView.isHidden = !cell.contentsTextView.isHidden
        searchResultTableView.beginUpdates()
        searchResultTableView.endUpdates()
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 300
    }
}

extension ScheduleSearchViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}
