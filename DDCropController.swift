//
//  DDCropController.swift
//
//  Created by Dmitry Dluzhnevsky on 09.10.2022.
//

import UIKit

protocol DDCropControllerDelegate: AnyObject {
    func didCropImage(_ image: UIImage?)
}

final class DDCropController: UIViewController {

    // MARK: - Internal Properties

    weak var delegate: DDCropControllerDelegate?

    // MARK: - Private Properties

    private var cropView: UIView {
        return overlayView.cropView
    }

    private var isWidthDominant: Bool {
        let cropViewRatio = cropView.frame.size.width / cropView.frame.size.height
        return currentImageRatio < cropViewRatio
    }

    private let image: UIImage
    private let cropRatio: CGFloat

    private let topView = UIView()
    private let imageView = UIImageView()
    private let overlayView: OverlayView

    private var currentImageRatio: CGFloat = 1

    private var imageCenterXConstraint: NSLayoutConstraint?
    private var imageCenterYConstraint: NSLayoutConstraint?
    private var lastImageCenterXOffset: CGFloat = 0
    private var lastImageCenterYOffset: CGFloat = 0

    private var imageWidthConstraint: NSLayoutConstraint?
    private var imageHeightConstraint: NSLayoutConstraint?
    private var lastStoredImageWidth: CGFloat = 0
    private var lastStoredImageHeight: CGFloat = 0

    private var lastOverlayRect: CGSize = .zero

    private let cancelButtonCaption: String
    private let cropButtonCaption: String

    // MARK: - Lifecycle

    convenience init(image: UIImage, cropRatio: CGFloat) {
        self.init(image: image,
                  cropRatio: cropRatio,
                  cancelButtonCaption: "Cancel",
                  cropButtonCaption: "Crop")
    }

    init(image: UIImage,
         cropRatio: CGFloat,
         cancelButtonCaption: String,
         cropButtonCaption: String) {
        self.image = image
        self.cropRatio = cropRatio
        self.cancelButtonCaption = cancelButtonCaption
        self.cropButtonCaption = cropButtonCaption
        self.overlayView = OverlayView(cropRatio: cropRatio)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground

        topView.clipsToBounds = true
        topView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(topView)

        imageView.image = self.image
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        topView.addSubview(imageView)

        let pinchGestureRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(pinch))
        imageView.addGestureRecognizer(pinchGestureRecognizer)

        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(pan))
        imageView.addGestureRecognizer(panGestureRecognizer)

        overlayView.translatesAutoresizingMaskIntoConstraints = false
        overlayView.isUserInteractionEnabled = false
        topView.addSubview(overlayView)

        let bottomContainerView = UIView()
        bottomContainerView.backgroundColor = .systemBackground
        bottomContainerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomContainerView)

        let bottomView = UIStackView()
        bottomView.axis = .horizontal
        bottomView.distribution = .fillEqually
        bottomView.translatesAutoresizingMaskIntoConstraints = false
        bottomContainerView.addSubview(bottomView)

        let cancelButton = UIButton()
        cancelButton.setTitle(cancelButtonCaption, for: .normal)
        cancelButton.setTitleColor(.label, for: .normal)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        cancelButton.addTarget(self, action: #selector(cropCancelPressed), for: .touchUpInside)
        bottomView.addArrangedSubview(cancelButton)

        let cropButton = UIButton()
        cropButton.setTitle(cropButtonCaption, for: .normal)
        cropButton.setTitleColor(.label, for: .normal)
        cropButton.translatesAutoresizingMaskIntoConstraints = false
        cropButton.addTarget(self, action: #selector(cropDonePressed), for: .touchUpInside)
        bottomView.addArrangedSubview(cropButton)

        NSLayoutConstraint.activate([
            topView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topView.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            imageView.topAnchor.constraint(lessThanOrEqualTo: cropView.topAnchor),
            imageView.bottomAnchor.constraint(greaterThanOrEqualTo: cropView.bottomAnchor),
            imageView.leadingAnchor.constraint(lessThanOrEqualTo: cropView.leadingAnchor),
            imageView.trailingAnchor.constraint(greaterThanOrEqualTo: cropView.trailingAnchor),

            overlayView.leadingAnchor.constraint(equalTo: topView.leadingAnchor),
            overlayView.centerXAnchor.constraint(equalTo: topView.centerXAnchor),
            overlayView.centerYAnchor.constraint(equalTo: topView.centerYAnchor),
            overlayView.topAnchor.constraint(equalTo: topView.topAnchor),

            bottomContainerView.topAnchor.constraint(equalTo: topView.bottomAnchor),
            bottomContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bottomContainerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            bottomView.topAnchor.constraint(equalTo: bottomContainerView.topAnchor),
            bottomView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bottomView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if lastOverlayRect != overlayView.frame.size {
            updateImageView()
            lastOverlayRect = overlayView.frame.size
        }
    }

    private func updateImageView() {
        imageView.image = image

        let ratio = image.size.width / image.size.height
        self.currentImageRatio = ratio

        imageCenterXConstraint?.isActive = false
        imageCenterXConstraint = nil
        let imageCenterXConstraint = imageView.centerXAnchor.constraint(equalTo: cropView.centerXAnchor)
        imageCenterXConstraint.priority = .defaultHigh
        self.imageCenterXConstraint = imageCenterXConstraint

        imageCenterYConstraint?.isActive = false
        imageCenterYConstraint = nil
        let imageCenterYConstraint = imageView.centerYAnchor.constraint(equalTo: cropView.centerYAnchor)
        imageCenterYConstraint.priority = .defaultHigh
        self.imageCenterYConstraint = imageCenterYConstraint

        guard cropView.frame != .zero else {
            return
        }

        let widthConstant: CGFloat
        let heightConstant: CGFloat

        if isWidthDominant {
            widthConstant = cropView.frame.width
            heightConstant = cropView.frame.width / ratio
        } else {
            widthConstant = cropView.frame.height * ratio
            heightConstant = cropView.frame.height
        }

        imageWidthConstraint?.isActive = false
        imageWidthConstraint = nil
        let imageWidthConstraint = imageView.widthAnchor.constraint(equalToConstant: widthConstant)
        imageWidthConstraint.priority = .required
        self.imageWidthConstraint = imageWidthConstraint

        imageHeightConstraint?.isActive = false
        imageHeightConstraint = nil
        let imageHeightConstraint = imageView.heightAnchor.constraint(equalToConstant: heightConstant)
        imageHeightConstraint.priority = .required
        self.imageHeightConstraint = imageHeightConstraint

        NSLayoutConstraint.activate([
            imageCenterXConstraint,
            imageCenterYConstraint,
            imageWidthConstraint,
            imageHeightConstraint
        ])

        lastStoredImageWidth = imageWidthConstraint.constant
        lastStoredImageHeight = imageHeightConstraint.constant
    }

    @objc
    private func cropDonePressed() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let croppedImage = makeCroppedImage()
        delegate?.didCropImage(croppedImage)
    }

    @objc
    private func cropCancelPressed() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        delegate?.didCropImage(nil)
    }

    @objc
    private func pinch(_ pinch: UIPinchGestureRecognizer) {
        guard let imageWidthConstraint = imageWidthConstraint,
              let imageHeightConstraint = imageHeightConstraint else {
            return
        }

        if pinch.state == .began {
            lastStoredImageWidth = imageWidthConstraint.constant
            lastStoredImageHeight = imageHeightConstraint.constant
        }

        let scale = pinch.scale
        let ratio = currentImageRatio

        let maxWidth: CGFloat
        let maxHeight: CGFloat
        if isWidthDominant {
            maxWidth = cropView.frame.width
            maxHeight = cropView.frame.width / ratio
        }
        else {
            maxWidth = cropView.frame.height * ratio
            maxHeight = cropView.frame.height
        }

        let width = max(lastStoredImageWidth * scale, maxWidth)
        let height = max(lastStoredImageHeight * scale, maxHeight)

        self.imageWidthConstraint?.constant = width
        self.imageHeightConstraint?.constant = height
    }

    @objc
    private func pan(_ pan: UIPanGestureRecognizer) {
        guard let imageCenterXConstraint = imageCenterXConstraint,
              let imageCenterYConstraint = imageCenterYConstraint else {
            return
        }

        if pan.state == .began {
            lastImageCenterXOffset = imageCenterXConstraint.constant
            lastImageCenterYOffset = imageCenterYConstraint.constant
        }

        let trans = pan.translation(in: self.view)

        let imageWidth = imageView.frame.width
        let imageHeight = imageView.frame.height

        let cropWidth = cropView.frame.width
        let cropHeight = cropView.frame.height

        var newX = lastImageCenterXOffset + trans.x
        if newX > (imageWidth - cropWidth) / 2 {
            newX = (imageWidth - cropWidth) / 2
        }
        else if newX < (cropWidth - imageWidth) / 2 {
            newX = (cropWidth - imageWidth) / 2
        }

        var newY = lastImageCenterYOffset + trans.y
        if newY > (imageHeight - cropHeight) / 2 {
            newY = (imageHeight - cropHeight) / 2
        }
        else if newY < (cropHeight - imageHeight) / 2 {
            newY = (cropHeight - imageHeight) / 2
        }

        self.imageCenterXConstraint?.constant = newX
        self.imageCenterYConstraint?.constant = newY
    }

    private func makeCroppedImage() -> UIImage? {
        let imageSize = image.size
        let width = cropView.frame.width / imageView.frame.width
        let height = cropView.frame.height / imageView.frame.height
        let x = (cropView.frame.origin.x - imageView.frame.origin.x) / imageView.frame.width
        let y = (cropView.frame.origin.y - imageView.frame.origin.y) / imageView.frame.height

        let cropFrame = CGRect(x: x * imageSize.width,
                               y: y * imageSize.height,
                               width: imageSize.width * width,
                               height: imageSize.height * height)

        guard let cgImage = image.cgImage?.cropping(to: cropFrame) else {
            return nil
        }

        let cropImage = UIImage(cgImage: cgImage, scale: 1, orientation: .up)
        return cropImage
    }

}

private final class OverlayView: UIView {

    // MARK: - Internal Properties

    let cropView = UIView()

    // MARK: - Private Properties

    private let fadeView = UIView()

    private var overlayViewWidthConstraint: NSLayoutConstraint?
    private var overlayViewHeightConstraint: NSLayoutConstraint?

    // MARK: - Lifecycle

    init(cropRatio: CGFloat) {
        super.init(frame: .zero)

        fadeView.translatesAutoresizingMaskIntoConstraints = false
        fadeView.isUserInteractionEnabled = false
        fadeView.backgroundColor = UIColor.black.withAlphaComponent(0.42)
        addSubview(fadeView)

        cropView.layer.borderWidth = 1
        cropView.layer.borderColor = UIColor.white.cgColor
        cropView.backgroundColor = UIColor.clear
        cropView.isUserInteractionEnabled = false
        cropView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cropView)

        NSLayoutConstraint.activate([
            fadeView.leadingAnchor.constraint(equalTo: leadingAnchor),
            fadeView.centerXAnchor.constraint(equalTo: centerXAnchor),
            fadeView.centerYAnchor.constraint(equalTo: centerYAnchor),
            fadeView.topAnchor.constraint(equalTo: topAnchor),

            cropView.centerXAnchor.constraint(equalTo: centerXAnchor),
            cropView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])

        updateCropRatio(cropRatio)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateFadeMask()

        guard overlayViewWidthConstraint == nil,
              overlayViewHeightConstraint == nil else {
            return
        }

        overlayViewWidthConstraint = widthAnchor.constraint(equalToConstant: frame.width)
        overlayViewWidthConstraint?.priority = .defaultHigh
        overlayViewWidthConstraint?.isActive = true

        overlayViewHeightConstraint = heightAnchor.constraint(equalToConstant: frame.height)
        overlayViewHeightConstraint?.priority = .defaultHigh
        overlayViewHeightConstraint?.isActive = true
    }

    // MARK: - Private Methods

    private func updateCropRatio(_ cropRatio: CGFloat) {
        let cropScreenShare: CGFloat = 0.9
        let cropViewWidthContraint: NSLayoutConstraint
        let cropViewHeightContraint: NSLayoutConstraint
        if cropRatio < 1 {
            cropViewHeightContraint = cropView.heightAnchor.constraint(equalTo: heightAnchor,
                                                                       multiplier: cropScreenShare)
            cropViewWidthContraint = cropView.widthAnchor.constraint(equalTo: heightAnchor,
                                                                     multiplier: cropScreenShare * cropRatio)
        }
        else {
            cropViewWidthContraint = cropView.widthAnchor.constraint(equalTo: widthAnchor,
                                                                     multiplier: cropScreenShare)
            cropViewHeightContraint = cropView.heightAnchor.constraint(equalTo: widthAnchor,
                                                                       multiplier: cropScreenShare / cropRatio)
        }
        cropViewWidthContraint.isActive = true
        cropViewHeightContraint.isActive = true
    }

    private func updateFadeMask() {
        let path = UIBezierPath(rect: cropView.frame)
        path.append(UIBezierPath(rect: fadeView.frame))
        let mask = CAShapeLayer()
        mask.fillRule = CAShapeLayerFillRule.evenOdd
        mask.path = path.cgPath
        fadeView.layer.mask = mask
    }

}
