//
//  ViewController.swift
//  Example
//
//  Created by VAndrJ on 19.08.2025.
//

import UIKit

final class ViewController<V: UIView>: UIViewController {
    private let contentView: V

    init(view: V) {
        self.contentView = view

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = contentView
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
