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

  // MARK: - IBOutlets
  @IBOutlet weak var segmentedControl: UISegmentedControl!
  @IBOutlet weak var imageView: UIImageView!
  @IBOutlet weak var nameLabel: UILabel!
  @IBOutlet weak var ratingLabel: UILabel!
  @IBOutlet weak var timesWornLabel: UILabel!
  @IBOutlet weak var lastWornLabel: UILabel!
  @IBOutlet weak var favoriteLabel: UILabel!
  
  // MARK: - Properties
  // 上下文管理对象
  var managedContext: NSManagedObjectContext!
  // 当前领带
  var currentBowtie: Bowtie!

  // MARK: - View Life Cycle
  override func viewDidLoad() {
    super.viewDidLoad()

    insertAndGetFirstRecord()
  }
  
  private func insertAndGetFirstRecord() {
    // 1 插入样例数据
    insertSampleData()
    
    // 2 设置查询对象
    let request: NSFetchRequest<Bowtie> = Bowtie.fetchRequest()
    let firstTitle = segmentedControl.titleForSegment(at: 0)!
    request.predicate = NSPredicate(format: "%K = %@", argumentArray: [#keyPath(Bowtie.searchKey), firstTitle])
    
    do {
      // 3 查询结果
      let results = try managedContext.fetch(request)
      
      //
      currentBowtie = results.first
      
      // 4 根据第一条数据展示页面
      populate(bowtie: results.first!)
    } catch let error as NSError {
      print("Could not fetch \(error),  userInfo: \(error.userInfo)")
    }
  }

  // MARK: - IBActions
  @IBAction func segmentedControl(_ sender: Any) {
    guard let control = sender as? UISegmentedControl,
      let selectedValue = control.titleForSegment(at: control.selectedSegmentIndex)
      else {
        return
    }
    
    let request: NSFetchRequest<Bowtie> = Bowtie.fetchRequest()
    request.predicate = NSPredicate(format: "%K = %@", argumentArray: [#keyPath(Bowtie.searchKey), selectedValue])
    
    do {
      // 3 查询结果
      let results = try managedContext.fetch(request)
      
      //
      currentBowtie = results.first
      
      // 4 根据第一条数据展示页面
      populate(bowtie: results.first!)
    } catch let error as NSError {
      print("Could not fetch \(error),  userInfo: \(error.userInfo)")
    }
  }

  @IBAction func wear(_ sender: Any) {
    let times = currentBowtie.timesWorn
    currentBowtie.timesWorn = times + 1
    currentBowtie.lastWorn = NSDate()
    
    do {
      try managedContext.save()
      populate(bowtie: currentBowtie)
    } catch let error as NSError {
      print("Could not fetch \(error),  userInfo: \(error.userInfo)")
    }
  }
  
  @IBAction func rate(_ sender: Any) {
    let alert = UIAlertController(title: "New Rating", message: "Rate this bow tie", preferredStyle: .alert)
    
    alert.addTextField { textField in
      textField.keyboardType = .decimalPad
    }
    
    let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
    
    let saveAction = UIAlertAction(title: "Save", style: .default) { [unowned self] action in
      if let textField = alert.textFields?.first {
        self.update(rating: textField.text)
      }
    }
    
    alert.addAction(cancelAction)
    alert.addAction(saveAction)
    
    present(alert, animated: true)
  }
  
  // Insert sample data
  func insertSampleData() {
    // 定义查询对象
    let fetch: NSFetchRequest<Bowtie> = Bowtie.fetchRequest()
    // 设置查询条件
    fetch.predicate = NSPredicate(format: "searchKey != nil")
    // 获取查询结果的记录条数
    let count = try! managedContext.count(for: fetch)
    // 如果大于0，则说明数据库文件已经存在
    if count > 0 {
      // SampleData.plish data already in Core Data
      return
    }
    // 获取数据库文件路径
    let path = Bundle.main.path(forResource: "SampleData", ofType: "plist")
    // 获取数据数组
    let dataArray = NSArray(contentsOfFile: path!)!
    // 遍历数据
    for dict in dataArray {
      // 获取实体
      let entity = NSEntityDescription.entity(forEntityName: "Bowtie", in: managedContext)!
      // 根据实体创建对象
      let bowtie = Bowtie(entity: entity, insertInto: managedContext)
      // 序列化字典数据为数组
      let btDict = dict as! [String: Any]
      // 设置ID
      bowtie.id = UUID(uuidString: btDict["id"] as! String)
      // 设置name
      bowtie.name = btDict["name"] as? String
      // 设置查询条件
      bowtie.searchKey = btDict["searchKey"] as? String
      // 设置评价信息
      bowtie.rating = btDict["rating"] as! Double
      // 获取原始颜色字典
      let colorDict = btDict["tintColor"] as! [String: Any]
      // 设置颜色
      bowtie.tintColor = UIColor.color(dict: colorDict)
      // 获取图片名称
      let imageName = btDict["imageName"] as? String
      // 创建图片对象
      let image = UIImage(named: imageName!)
      // 将图片对象转换成 Data 对象
      let photoData = UIImagePNGRepresentation(image!)!
      // 设置图片的Data属性
      bowtie.photoData = NSData(data: photoData)
      // 设置最后佩戴时间
      bowtie.lastWorn = btDict["lastWorn"] as? NSDate
      // 获取 NSNumber 类型的佩戴次数
      let timesNumber = btDict["timesWorn"] as! NSNumber
      // 转换成 32 位的佩戴次数
      bowtie.timesWorn = timesNumber.int32Value
      // 设置是否喜爱
      bowtie.isFavorite = btDict["isFavorite"] as! Bool
      // 设置 url
      bowtie.url = URL(string: btDict["url"] as! String)
    }
    // 保存数据
    try! managedContext.save()
  }
  
  // 展示数据
  func populate(bowtie: Bowtie) {
    // 如果图片、最后一次佩戴和喜欢的颜色有一个为空值，则直接退出
    guard let imageData = bowtie.photoData as Data?,
      let lastWorn = bowtie.lastWorn as Date?,
      let tintColor = bowtie.tintColor as? UIColor else {
        return
    }
    // 设置图片
    imageView.image = UIImage(data: imageData)
    // 设置文本
    nameLabel.text = bowtie.name
    // 设置投票文本
    ratingLabel.text = "Rating: \(bowtie.rating)/5"
    // 设置佩戴次数
    timesWornLabel.text = "# times worn: \(bowtie.timesWorn)"
    // 日期格式化对象
    let dateFormatter = DateFormatter()
    // 设置日期样式
    dateFormatter.dateStyle = .short
    // 设置时间样式
    dateFormatter.timeStyle = .none
    // 设置最后一次佩戴的时间
    lastWornLabel.text = "Last worn: " + dateFormatter.string(from: lastWorn)
    // 喜欢标签是否隐藏
    favoriteLabel.isHidden = !bowtie.isFavorite
    // 设置颜色
    view.tintColor = tintColor
  }
  
  // 更新投票
  func update(rating: String?) {
    guard let ratingString = rating, let rating = Double(ratingString) else {
      return
    }
    
    do {
      currentBowtie.rating = rating
      try managedContext.save()
      populate(bowtie: currentBowtie)
    } catch let error as NSError {
      
      if error.domain == NSCocoaErrorDomain &&
        (error.code == NSValidationNumberTooLargeError ||
        error.code == NSValidationNumberTooSmallError) {
        rate(currentBowtie)
      } else {
        print("Could not fetch \(error),  userInfo: \(error.userInfo)")
      }
    }
  }
}


private extension UIColor {
  static func color(dict: [String: Any]) -> UIColor? {
    guard let red = dict["red"] as? NSNumber,
      let green = dict["green"] as? NSNumber,
      let blue = dict["blue"] as? NSNumber else {
        return nil
    }
    return UIColor(displayP3Red: CGFloat(truncating: red) / 255.0,
                   green: CGFloat(truncating: green) / 255.0,
                   blue: CGFloat(truncating: blue) / 255.0,
                   alpha: 1.0)
  }
}
