//
//  ViewController.swift
//  LiquidGlassDemo
//
//  Created by Robert Ryan on 9/15/25.
//

import UIKit

class ViewController: UICollectionViewController {
    // MARK: - Data
    private var dataSource: UICollectionViewDiffableDataSource<Section, Item>!

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        configureLayoutIfNeeded()
        configureDataSource()
        applyInitialSnapshot()
    }
}

// MARK: - Layout

private extension ViewController {
    func configureLayoutIfNeeded() {
        let layout = UICollectionViewCompositionalLayout { (sectionIndex: Int, layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(100))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .absolute(100))
            let group = NSCollectionLayoutGroup.vertical(layoutSize: groupSize, subitems: [item])
            group.interItemSpacing = .fixed(0)

            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = 10
            section.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
            return section
        }
        collectionView.setCollectionViewLayout(layout, animated: false)
    }
}

// MARK: - Data source

private extension ViewController {
    func configureDataSource() {
        // Cell registration for a custom hex pattern cell
        let registration = UICollectionView.CellRegistration<HexPatternCell, Item> { cell, _, item in
            let color = UIColor(hue: CGFloat(item.hue), saturation: 0.8, brightness: 0.9, alpha: 1.0)
            cell.configure(primaryColor: color, index: item.index)
        }

        dataSource = UICollectionViewDiffableDataSource<Section, Item>(collectionView: collectionView) { (collectionView: UICollectionView, indexPath: IndexPath, itemIdentifier: Item) -> UICollectionViewCell? in
            collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: itemIdentifier)
        }
    }

    func applyInitialSnapshot() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, Item>()
        snapshot.appendSections([Section.main])

        // Generate 100 visually distinct colors
        var items: [Item] = []
        items.reserveCapacity(100)
        for i in 0..<100 {
            let hue = Double(i) / 100
            items.append(Item(index: i + 1, hue: hue))
        }

        snapshot.appendItems(items, toSection: Section.main)
        dataSource.apply(snapshot, animatingDifferences: false)
    }
}

// MARK: Section/Item

extension ViewController {
    nonisolated enum Section: Int, CaseIterable {
        case main
    }

    nonisolated struct Item: Hashable, Sendable {
        let id = UUID()
        let index: Int
        let hue: Double
    }
}

// MARK: - Hex Pattern Cell

private extension ViewController {
    final class HexPatternCell: UICollectionViewCell {
        private let patternView = HexPatternView()
        private let numberLabel = PaddedLabel()

        override init(frame: CGRect) {
            super.init(frame: frame)
            commonInit()
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            commonInit()
        }

        private func commonInit() {
            contentView.backgroundColor = .systemBackground
            contentView.layer.cornerRadius = 12
            contentView.layer.masksToBounds = true

            patternView.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(patternView)
            NSLayoutConstraint.activate([
                patternView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                patternView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                patternView.topAnchor.constraint(equalTo: contentView.topAnchor),
                patternView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])

            numberLabel.translatesAutoresizingMaskIntoConstraints = false
            numberLabel.font = UIFont.preferredFont(forTextStyle: .headline)
            numberLabel.adjustsFontForContentSizeCategory = true
            numberLabel.textColor = .label
            numberLabel.backgroundColor = .systemBackground.withAlphaComponent(0.85)
            numberLabel.textAlignment = .right
            numberLabel.numberOfLines = 1
            numberLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
            numberLabel.setContentCompressionResistancePriority(.required, for: .vertical)
            numberLabel.contentInsets = UIEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
            numberLabel.layer.cornerRadius = 8
            numberLabel.layer.masksToBounds = true
            contentView.addSubview(numberLabel)
            NSLayoutConstraint.activate([
                numberLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
                numberLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
            ])
        }

        func configure(primaryColor: UIColor, index: Int) {
            numberLabel.text = "\(index)"
            patternView.primaryColor = primaryColor
        }
    }
}

// MARK: - Hex Pattern View

private extension ViewController {
    final class HexPatternView: UIView {
        var primaryColor: UIColor = .systemBlue { didSet { setNeedsDisplay() } }

        // Tunables for the pattern
        private let dotDiameter: CGFloat = 12
        private let dotSpacing: CGFloat = 6 // spacing between dot edges horizontally

        override class var layerClass: AnyClass { CALayer.self }

        override func draw(_ rect: CGRect) {
            guard let context = UIGraphicsGetCurrentContext() else { return }
            context.clear(rect)

            let diameter = dotDiameter
            let radius = diameter / 2
            let horizontalStep = diameter + dotSpacing
            // For a hex grid, vertical step is sqrt(3)/2 * horizontalStep
            let verticalStep = horizontalStep * CGFloat(sqrt(3)) / 2

            let insetRect = rect.insetBy(dx: 10, dy: 10) // small inner padding so circles don't clip

            // Derive two colors to make the pattern more visually busy
            let base = primaryColor
            var hue: CGFloat = 0, sat: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
            base.getHue(&hue, saturation: &sat, brightness: &brightness, alpha: &alpha)
            let alt = UIColor(hue: hue, saturation: min(1, sat * 0.6 + 0.2), brightness: min(1, brightness * 1.1), alpha: alpha)

            let baseColor = base.cgColor
            let altColor = alt.cgColor

            // Pre-create a path for a circle
            let circlePath = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: diameter, height: diameter)).cgPath

            var row = 0
            var y = insetRect.minY + radius
            while y <= insetRect.maxY - radius {
                // Offset every other row by half a step to form hex tiling
                let xOffset = (row % 2 == 0) ? 0 : horizontalStep / 2
                var x = insetRect.minX + radius + xOffset
                while x <= insetRect.maxX - radius {
                    context.saveGState()
                    context.translateBy(x: x - radius, y: y - radius)
                    context.addPath(circlePath)
                    context.setFillColor(((row + Int((x - insetRect.minX) / horizontalStep)) % 2 == 0) ? baseColor : altColor)
                    context.fillPath()
                    context.restoreGState()
                    x += horizontalStep
                }
                row += 1
                y += verticalStep
            }
        }
    }

    final class PaddedLabel: UILabel {
        var contentInsets: UIEdgeInsets = .zero { didSet { invalidateIntrinsicContentSize() } }

        override func drawText(in rect: CGRect) {
            let insetRect = rect.inset(by: contentInsets)
            super.drawText(in: insetRect)
        }

        override var intrinsicContentSize: CGSize {
            let size = super.intrinsicContentSize
            return CGSize(width: size.width + contentInsets.left + contentInsets.right,
                          height: size.height + contentInsets.top + contentInsets.bottom)
        }

        override func sizeThatFits(_ size: CGSize) -> CGSize {
            let target = CGSize(width: size.width - contentInsets.left - contentInsets.right,
                                height: size.height - contentInsets.top - contentInsets.bottom)
            let fitted = super.sizeThatFits(target)
            return CGSize(width: fitted.width + contentInsets.left + contentInsets.right,
                          height: fitted.height + contentInsets.top + contentInsets.bottom)
        }
    }
}
