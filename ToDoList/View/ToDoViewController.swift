//
//  ViewController.swift
//  ToDoList
//
//  Created by 최광현 on 2021/02/13.
//

import UIKit
import SnapKit
import FSCalendar
import CoreData
import RxSwift
import RxCocoa

class ToDoViewController: UIViewController {
    
    
    // MARK: Calendar
    private let toDoCalendar: ToDoCalendar = {
        let view = ToDoCalendar(frame: .init(x: 0, y: 0, width: 100, height: 100))
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // MARK: Schedule Table button
    private let scheduleTbView: UITableView = {
        let view = UITableView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.separatorStyle = .none
        return view
    }()
    
    // MARK: No Schedule Label for ScheduleTbView
    private let noScheduleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // MARK: Schedule Add button
    private let addButton: UIButton = {
        let button = UIButton()
        button.setImage(UIImage(systemName: "plus"), for: .normal)
        button.tintColor = .systemBackground
        button.translatesAutoresizingMaskIntoConstraints = false
        button.layer.backgroundColor = UIColor.label.cgColor
        button.layer.cornerRadius = 25
        return button
    }()
    
    // MARK: 선택된 날
    private var selectedDate = Date()
    // MARK: 1주 간의 date를 표시하기 위한 변수
    private var dates: [Date]?
    
    private var selectedIndexPath: IndexPath?
    
    private let scheduleTableCellId = "ScheduleCell"
    private let calendarCellId = "DayCell"
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월 d일 일정 없음"
        return formatter
    }()
    private let viewModel: ToDoViewModel = ToDoViewModel()
    private let userConfigurationViewModel = UserConfigurationViewModel.shared
    private var eventCount: [Int] = []
    private var disposeBag = DisposeBag()
    private var numberOfSectionInSchduleTable: Int = 0
        
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        // 스케쥴 테이블 dataSource, delegate, cell 등록
        // 일정 추가 버튼 추가
        configureSubviews()
        guard let today = toDoCalendar.today else {return}
        
        viewModel.currentMonthRelay
            .accept(toDoCalendar.currentPage.startOfDay)
        
//        // 폰트 체크 하기
//        UIFont.familyNames.sorted().forEach{ familyName in
//           print("*** \(familyName) ***")
//           UIFont.fontNames(forFamilyName: familyName).forEach { fontName in
//               print("\(fontName)")
//           }
//           print("---------------------")
//        }
        
        /// Get schedules at selected Date
        viewModel.selectedDatesRelay
            .accept([today])
        
        /// Get the number of schedules at selected Date
        /// If the number of schedules at selected Date is greater than 0, then noScheduleLabel is going to be hidden
        /// else noScheduleLabel will be shown in the middle of the scheduleTbView
        toDoCalendar.delegate = self
        toDoCalendar.dataSource = self
    }
    
    override func viewWillAppear(_ animated: Bool) {
        print("viewWillAppear")
        
        toDoCalendar.appearance.headerTitleColor = UIColor.label
        toDoCalendar.appearance.weekdayTextColor = UIColor.label
        
        scheduleTbView.rx
            .setDelegate(self)
            .disposed(by: disposeBag)
        
        viewModel.schedulesRelay
            .flatMap({Observable.from($0)})
            .subscribe(onNext:{ [weak self] schedules in
                guard let strongSelf = self, let selectedDate = strongSelf.toDoCalendar.selectedDate else {return}
                strongSelf.noScheduleLabel.text = strongSelf.dateFormatter.string(from: selectedDate)
                strongSelf.noScheduleLabel.isHidden = schedules.count > 0 ? true : false
            })
            .disposed(by: disposeBag)
        
                              
        /// UITableViewDelegate func(cellForRow:)
        scheduleTbView.rx
            .itemSelected
            .subscribe(onNext: { [weak self] indexPath in
                // 선택되지 않은 cell들 Hidden 처리
                let cells = self?.scheduleTbView.visibleCells as? [ScheduleCell]
                _ = cells?.map {
                    if self?.scheduleTbView.indexPath(for: $0) != indexPath {
                        $0.contentsTextView.isHidden = true
                    }
                }
                guard let cell = self?.scheduleTbView.cellForRow(at: indexPath) as? ScheduleCell else {return}
                self?.viewModel.selectedScheduleRelay.accept(cell.schedule)
                cell.contentsTextView.isHidden = !cell.contentsTextView.isHidden
                cell.scheduleEditDelegate = self
                if cell.contentsTextView.isHidden {
                    self?.selectedIndexPath = nil
                } else{
                    self?.selectedIndexPath = indexPath
                }
                self?.scheduleTbView.beginUpdates()
                self?.scheduleTbView.endUpdates()
            }, onCompleted: {
                print("cell touched")
            })
            .disposed(by: disposeBag)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        print("view didlayout subview")
    }
    
    override func viewDidDisappear(_ animated: Bool) {
//        toDoCalendar.delegate = nil
//        toDoCalendar.dataSource = nil
        // MARK: 화면 전환할 때 dispose 해야함
        disposeBag = DisposeBag()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        // MARK: Waring 발생 UITableViewDelegate의 cellForRowAt 함수
        // 해결방법 : viewDidLoad -> viewDidApper로 이동
        // Git에도 에러 Report 되어 있음
        
        viewModel.schedulesRelay
            .flatMap({ Observable.from($0)})
            .bind(to: scheduleTbView.rx.items(cellIdentifier: ScheduleCell.cellId, cellType: ScheduleCell.self)) {
                (index: Int, schedule: Schedule, cell: ScheduleCell) in
                cell.selectionStyle = .none
                cell.contentsTextView.isHidden = true
                cell.schedule = schedule
            }
            .disposed(by: disposeBag)
        
        
        userConfigurationViewModel
            .fontNameRelay?
            .filter {$0 != nil}
            .subscribe(onNext: { [weak self] in
                self?.toDoCalendar.appearance.headerTitleFont = UIFont(name: $0!, size: 20)
                self?.toDoCalendar.appearance.weekdayFont = UIFont(name: $0!, size: 15)
                self?.toDoCalendar.appearance.titleFont = UIFont(name: $0!, size: 12)
            })
            .disposed(by: disposeBag)
        
        userConfigurationViewModel.weekDaylocaleRelay?
            .filter {$0 != nil}
            .subscribe(onNext: { [weak self] in
                self?.toDoCalendar.locale = Locale(identifier: $0!)
            })
            .disposed(by: disposeBag)
        
    }
    
    // MARK: toDoCalendar, ScheduleTbView, addButton 설정
    func configureSubviews() {
        // toDoCalendar 설정
        view.addSubview(toDoCalendar)
        toDoCalendar.snp.makeConstraints{
            $0.top.leading.trailing.equalTo(view.safeAreaLayoutGuide)
            $0.height.equalTo(300)
        }
        toDoCalendar.register(FSCalendarCell.self, forCellReuseIdentifier: calendarCellId)
        toDoCalendar.scope = .month
        toDoCalendar.layoutMargins = .zero
        toDoCalendar.scrollDirection = .horizontal
        toDoCalendar.backgroundColor = .systemBackground
        toDoCalendar.needsAdjustingViewFrame = true
        toDoCalendar.placeholderType = .none
        toDoCalendar.select(selectedDate)
        viewModel.selectedDatesRelay.accept(toDoCalendar.selectedDates)
        let scopeGesture = UIPanGestureRecognizer(target: toDoCalendar, action: #selector(toDoCalendar.handleScopeGesture(_:)))
        toDoCalendar.addGestureRecognizer(scopeGesture)
        
        /// Add scheduleTbView and set layout
        view.addSubview(scheduleTbView)
        scheduleTbView.snp.makeConstraints{
            $0.top.lessThanOrEqualTo(toDoCalendar.snp.bottom)
            $0.bottom.leading.trailing.equalTo(view.safeAreaLayoutGuide)
        }
        scheduleTbView.register(ScheduleCell.self, forCellReuseIdentifier: ScheduleCell.cellId)
        scheduleTbView.backgroundColor = .systemBackground
        
        /// Add NoScheduleLabel to scheduleTbView and set layout to the center of the scheduleTbView
        scheduleTbView.addSubview(noScheduleLabel)
        noScheduleLabel.snp.makeConstraints {
            $0.centerY.equalTo(scheduleTbView.snp.centerY)
            $0.centerX.equalToSuperview()
        }
        
        /// set Naviagtion appearance
        setNavigationAppearance()
        /// add Schedule add button in the view and set layouts
        view.addSubview(addButton)
        addButton.snp.makeConstraints{
            $0.leading.equalTo(view.safeAreaLayoutGuide.snp.trailing).offset(-70)
            $0.top.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-70)
            $0.width.height.equalTo(50)
        }
        addButton.addTarget(self, action: #selector(touchAddButton(_:)), for: .touchUpInside)
    }
    
    // MARK: 네비게이션바 모양을 투명하게 바꿈
    func setNavigationAppearance() {
        let navigationAppearance = UINavigationBarAppearance()
        navigationAppearance.configureWithTransparentBackground()
        self.navigationController?.navigationBar.standardAppearance = navigationAppearance
    }
    
    // MARK: CoreData 실험 위한 데이터 추가용
    func addSchedule() {
        let context = PersistantManager.shared.context
        guard let entity = NSEntityDescription.entity(forEntityName: "Schedule", in: context) else {return}
        do {
            let schedule = NSManagedObject(entity: entity, insertInto: context)
            let title = "test"
            let start = Date()
            let end = start + 60 * 60
            let alarm = false
            schedule.setValue(title, forKey: "title")
            schedule.setValue(start, forKey: "start")
            schedule.setValue(end, forKey: "end")
            schedule.setValue(alarm, forKey: "alarm")
            try context.save()
        } catch {
            print(error.localizedDescription)
        }
    }
    
    // MARK: 일정 추가 버튼 클릭시 이벤트 발생
    @objc func touchAddButton(_ sender: UIButton){
        guard let _ = toDoCalendar.selectedDate else {
            let alert = UIAlertController(title: "일정 추가", message: "날짜를 선택해주세요.", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "확인", style: .default)
            alert.addAction(okAction)
            present(alert, animated: true, completion: nil)
            return
        }
        presentScheduleAddView()
    }
    
    // MARK: 일정 추가 버튼 클릭시 일정 추가 버튼 팝업
    func presentScheduleAddView() {
        guard let selectedDate = toDoCalendar.selectedDate else {return}
        let originPos = self.addButton.center
        let diff = originPos.x - view.center.x
        UIView.animate(withDuration: 0.3, animations: {
            self.addButton.transform = CGAffineTransform(translationX: -diff, y: 0)
        }, completion: { [weak self] _ in
            print("move circle completed")
            let scheduleAddVC = ScheduleViewController()
            print("presentScheduleAddView \(selectedDate.toLocalTime())")
            // viewModel에 시작 시간 입력
            scheduleAddVC.viewModel
                .editableRelay
                .accept(false)
            scheduleAddVC.viewModel
                .startEpochInputRelay
                .accept(selectedDate.timeIntervalSince1970)
            // scheduleAddVC가 dismiss될 때의 동작 정의
            scheduleAddVC.completionHandler = { [weak self] in
                print("scheduleAddVC dismissed")
                self?.viewModel.selectedDatesRelay.accept([selectedDate])
                self?.toDoCalendar.reloadData()
                self?.scheduleTbView.reloadData()
            }
            scheduleAddVC.modalPresentationStyle = .fullScreen
            self?.present(scheduleAddVC, animated: true, completion: {
                UIView.animate(withDuration: 0.3, animations: {
                self?.addButton.transform = CGAffineTransform(translationX: 0, y: 0)
                })
            })
        })
    }

}


extension ToDoViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let cell = tableView.cellForRow(at: indexPath) as? ScheduleCell else {return nil}
        viewModel
            .selectedScheduleRelay
            .accept(cell.schedule)
        let action = UIContextualAction(style: .destructive, title: "삭제"){
            [weak self] (_, _, completionHandler) in
            // 삭제 액션이 발생했음을 viewModel에 알림
            self?
                .viewModel
                .deletedActionRelay
                .accept(())
            self?.toDoCalendar.reloadData()
            completionHandler(true)
        }
        action.backgroundColor = .systemPink
        return UISwipeActionsConfiguration(actions: [action])
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard let cell = tableView.cellForRow(at: indexPath) as? ScheduleCell else {return 100}
        guard let selectedIndexPath = selectedIndexPath else {return 100}
        if selectedIndexPath == indexPath {
            return 90 + cell.contentsTextView.contentSize.height
        } else {
            return 100
        }
    }    
}

extension ToDoViewController: FSCalendarDataSource, FSCalendarDelegate, FSCalendarDelegateAppearance  {
    
    // MARK: 이벤트 수 받아오는 로직에 대해서 고민이 필요함.
    func calendar(_ calendar: FSCalendar, numberOfEventsFor date: Date) -> Int {
        let startOfDay = date.startOfDay.toLocalTime()
//        let schedules = self.getSchedule(of: startOfDay)
//        return schedules?.count ?? 0
        var schedules = 0
        viewModel.eventForDateInputRelay.accept(startOfDay)
        viewModel.eventForDateOutputRelay
            .subscribe(onNext: {
                schedules = $0
            }).disposed(by: disposeBag)
        return schedules
    }
    
    func calendar(_ calendar: FSCalendar, cellFor date: Date, at position: FSCalendarMonthPosition) -> FSCalendarCell {
        let cell = calendar.dequeueReusableCell(withIdentifier: calendarCellId, for: date, at: position)
        return cell
    }
    
    func calendar(_ calendar: FSCalendar, appearance: FSCalendarAppearance, titleDefaultColorFor date: Date) -> UIColor? {
        switch date.weekDay{
            case 7:
                return UIColor.systemGray
            case 2...6:
                return UIColor.label
            default:
                return UIColor.systemPink
        }
    }
    
    func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        viewModel.selectedDatesRelay.accept(calendar.selectedDates)
    }
    
    func calendar(_ calendar: FSCalendar, boundingRectWillChange bounds: CGRect, animated: Bool) {
        calendar.snp.updateConstraints({ (make) in
            make.height.equalTo(bounds.height)
        })
        view.layoutIfNeeded()
    }
    
    func calendarCurrentPageDidChange(_ calendar: FSCalendar) {
        viewModel.currentMonthRelay.accept(toDoCalendar.currentPage.startOfDay)
    }
    
    func calendar(_ calendar: FSCalendar, appearance: FSCalendarAppearance, eventDefaultColorsFor date: Date) -> [UIColor]? {
        return [.label]
    }
    
    func calendar(_ calendar: FSCalendar, appearance: FSCalendarAppearance, eventSelectionColorsFor date: Date) -> [UIColor]? {
        return [.systemPurple, .systemYellow, .systemGreen]
    }
}

extension ToDoViewController: ScheduleCellDelegate {
    func edit(_ schedule: Schedule) {
        guard let selectedDate = toDoCalendar.selectedDate else {return}
        let editViewController = ScheduleViewController()
        editViewController
            .viewModel
            .editableRelay
            .accept(true)
        editViewController
            .viewModel
            .scheduleRelay
            .accept(schedule)
        editViewController.modalPresentationStyle = .fullScreen
        present(editViewController, animated: true, completion: nil)
        editViewController.completionHandler = { [weak self] in
            print("scheduleAddVC dismissed")
            self?.viewModel
                .selectedDatesRelay
                .accept([selectedDate])
            self?.toDoCalendar.reloadData()
            self?.scheduleTbView.reloadData()
        }
    }
}
