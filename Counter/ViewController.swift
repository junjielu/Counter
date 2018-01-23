//
//  ViewController.swift
//  Counter
//
//  Created by 陆俊杰 on 2018/1/23.
//  Copyright © 2018年 陆俊杰. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

class ViewController: UIViewController {
    @IBOutlet weak var increaseButton: UIButton!
    @IBOutlet weak var decreaseButton: UIButton!
    @IBOutlet weak var countLabel: UILabel!
    
    let disposeBag = DisposeBag()
    
    typealias State = Int
    enum Event {
        case increment
        case decrement
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let feedback: (Observable<State>) -> Observable<Event> = { [weak self] state in
            guard let strongSelf = self,
                let increase = self?.increaseButton,
                let decrease = self?.decreaseButton,
                let label = self?.countLabel else { return Observable.empty() }
            state.map(String.init).bind(to: label.rx.text).disposed(by: strongSelf.disposeBag)
            let events = [
                increase.rx.tap.map { Event.increment },
                decrease.rx.tap.map { Event.decrement }
            ]
            return Observable.merge(events)
        }
        
        Observable.system(
            initialState: 0,
            reduce: { state, event -> State in
                switch event {
                case .increment:
                    return state + 1
                case .decrement:
                    return state - 1
                }
        },
            scheduler: MainScheduler.instance,
            feedbacks: [feedback])
            .subscribe()
            .disposed(by: disposeBag)
    }
}

extension Observable where E == Any {
    typealias Feedback<State, Event> = (Observable<State>) -> Observable<Event>
    
    static func system<State, Event>(initialState: State,
                                     reduce: @escaping (State, Event) -> State,
                                     scheduler: ImmediateSchedulerType,
                                     feedbacks: [Feedback<State, Event>]) -> Observable<State> {
        return Observable<State>.deferred {
            let replaySubject = ReplaySubject<State>.create(bufferSize: 1)
            
            let events: Observable<Event> = Observable<Event>.merge(feedbacks.map { feedback in
                let state = replaySubject.asObservable()
                return feedback(state)
            })
            
            return events.scan(initialState, accumulator: reduce)
                .do(onNext: { output in
                    replaySubject.onNext(output)
                }, onSubscribed: {
                    replaySubject.onNext(initialState)
                })
                .subscribeOn(scheduler)
                .startWith(initialState)
                .observeOn(scheduler)
        }
    }
}
