/// Copyright (c) 2018 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import UIKit
import CoreData

class ViewController: UIViewController {

  // MARK: - Properties
  private let filterViewControllerSegueIdentifier = "toFilterViewController"
  private let venueCellIdentifier = "VenueCell"

  var coreDataStack: CoreDataStack!
  // Stored fetch requests
  var fetchRequest: NSFetchRequest<Venue>?
  var venues: [Venue] = []
  

  // MARK: - IBOutlets
  @IBOutlet weak var tableView: UITableView!

  // MARK: - View Life Cycle
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Stored fetch requests
    guard let model = coreDataStack.managedContext.persistentStoreCoordinator?.managedObjectModel,
      let fetchRequest = model.fetchRequestTemplate(forName: "FetchRequest") as? NSFetchRequest<Venue> else {
      return
    }
    
    self.fetchRequest = fetchRequest
    fetchAndReload()
  }

  // MARK: - Navigation
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    guard segue.identifier == filterViewControllerSegueIdentifier,
      let navController = segue.destination as? UINavigationController,
      let filterVC = navController.topViewController as? FilterViewController else {
      return
    }
    
    filterVC.coreDataStack = coreDataStack
  }
}

// MARK: - IBActions
extension ViewController {

  @IBAction func unwindToVenueListViewController(_ segue: UIStoryboardSegue) {
  }
}

// MARK: - Helper methods
extension ViewController {
  func fetchAndReload() {
    guard let fetchRequest = fetchRequest else { return }
    
    do {
      venues = try coreDataStack.managedContext.fetch(fetchRequest)
      tableView.reloadData()
    } catch let error as NSError {
      print("Could not fetch \(error), \(error.userInfo)")
    }
  }
}

// MARK: - UITableViewDataSource
extension ViewController: UITableViewDataSource {

  
  
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return venues.count
    //return 10
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: venueCellIdentifier, for: indexPath)
    
    let venue = venues[indexPath.row]
    cell.textLabel?.text = venue.name // "Bubble Tea Venue"
    cell.detailTextLabel?.text = venue.priceInfo?.priceCategory // "Price Info"
    return cell
  }
}

// MARK: - UITableViewDelegate
extension ViewController: UITableViewDelegate {
  func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    return 35
  }
}
