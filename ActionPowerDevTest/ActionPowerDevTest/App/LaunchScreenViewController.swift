import UIKit
import SwiftUI

class LaunchScreenViewController: UIViewController {
    private let logoLabel: UILabel = {
        let label = UILabel()
        label.text = "Launching..."
        label.font = .boldSystemFont(ofSize: 22)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        return label
    }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        indicator.startAnimating()
        return indicator
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.backgroundColor = .systemBackground
        
        view.addSubview(logoLabel)
        view.addSubview(activityIndicator)
        
        NSLayoutConstraint.activate([
            logoLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            activityIndicator.topAnchor.constraint(equalTo: logoLabel.bottomAnchor, constant: 12),
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }
}

#if canImport(SwiftUI) && DEBUG
import SwiftUI

struct LaunchScreenViewController_Previews: PreviewProvider {
    static var previews: some View {
        UIViewControllerPreview {
            LaunchScreenViewController()
        }
        .edgesIgnoringSafeArea(.all)
    }
}

struct UIViewControllerPreview<ViewController: UIViewController>: UIViewControllerRepresentable {
    let viewController: ViewController

    init(_ builder: @escaping () -> ViewController) {
        viewController = builder()
    }

    func makeUIViewController(context: Context) -> ViewController {
        viewController
    }

    func updateUIViewController(_ uiViewController: ViewController, context: Context) {
    }
}
#endif
