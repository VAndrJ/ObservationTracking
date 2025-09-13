//
//  ViewController.swift
//  Example
//
//  Created by VAndrJ on 19.08.2025.
//

import UIKit

final class ViewController<V: ScreenView>: UIViewController {
    private let contentView: V

    init(view: V) {
        self.contentView = view

        super.init(nibName: nil, bundle: nil)

        view.controller = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = contentView
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        contentView.viewWillAppear(animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        contentView.viewDidDisappear(animated)
    }
}

protocol ScreenView: UIView {
    var controller: UIViewController? { get set }
    var navigationController: UINavigationController? { get }

    func viewWillAppear(_ animated: Bool)
    func viewDidDisappear(_ animated: Bool)
    func push<V: ScreenView>(screen: V, animated: Bool)
}

extension ScreenView {
    
    func push<V: ScreenView>(screen: V) {
        push(screen: screen, animated: true)
    }
}

class BaseView<VM: Observable>: UIView {
    let viewModel: VM

    init(viewModel: VM) {
        self.viewModel = viewModel

        super.init(frame: .zero)

        addElements()
        configure()
        bind()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func addElements() {}

    func configure() {}

    func bind() {}
}

class BaseScreenView<VM: Observable>: BaseView<VM>, ScreenView {
    weak var controller: UIViewController?
    var navigationController: UINavigationController? { controller?.navigationController }

    func viewWillAppear(_ animated: Bool) {}

    func viewDidDisappear(_ animated: Bool) {}

    func push<V: ScreenView>(screen: V, animated: Bool) {
        navigationController?.pushViewController(
            ViewController(view: screen),
            animated: animated
        )
    }
}

extension UIView {

    func addAutolayoutSubview(_ subview: UIView) {
        subview.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subview)
    }

    func addAutolayoutSubviews(_ subviews: UIView...) {
        subviews.forEach { addAutolayoutSubview($0) }
    }
}

protocol Applyable {}

extension Applyable where Self: AnyObject {
    
    @discardableResult
    func apply(_ closure: (Self) -> Void) -> Self {
        closure(self)

        return self
    }
}

extension NSObject: Applyable {}

class BaseButton: UIButton {

    convenience init(title: String, action: @escaping () -> Void) {
        self.init(type: .system)

        setTitle(title, for: .normal)
        addAction(UIAction { _ in action() }, for: .touchUpInside)
    }
}
