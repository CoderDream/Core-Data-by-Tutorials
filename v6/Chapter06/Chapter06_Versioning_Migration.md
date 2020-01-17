
# Chapter 6: Versioning & Migration

You've seen how to design your data model and NSManagedObject subclasses in your Core Data apps. During app development, well before the ship date, thorough testing can help iron out the data model. However, changes in app usage, design or features after an app's release will inevitably lead to changes in the data model. What do you do then?

You can't predict the future, but with Core Data, you can migrate toward the future with every new release of your app. The migration process will update data created with a previous version of the data model to match the current data model.

This chapter discusses the many aspects of Core Data migrations by walking you through the evolution of a note-taking app's data model.

You'll start with a simple app with only a single entity in its data model. As you add more features and data to the app, the migrations you do in this chapter will become progressively more complex.

Let the great migration begin!

# When to migrate

When is a migration necessary? The easiest answer to this common question is "when you need to make changes to the data model."

However, there are some cases in which you can avoid a migration. If an app is using Core Data merely as an offline cache, when you update the app, you can simply delete and rebuild the data store. This is only possible if the source of truth for your user's data isn't in the data store. In all other cases, you'll need to safeguard your user's data.

That said, any time it's impossible to implement a design change or feature request without changing the data model, you'll need to create a new version of the data model and provide a migration path.

# The migration process

When you initialize a Core Data stack, one of the steps involved is adding a store to the persistent store coordinator. When you encounter this step, Core Data does a few things prior to adding the store to the coordinator. First, Core Data analyzes the store's model version. Next, it compares this version to the coordinator's configured data model. If the store's model version and the coordinator's model version don't match, Core Data will perform a migration, when enabled.

```
Note: If migrations aren’t enabled, and the store is incompatible with the
model, Core Data will simply not attach the store to the coordinator and
specify an error with an appropriate reason code.
```

To start the migration process, Core Data needs the original data model and the destination model. It uses these two versions to load or create a mapping model for the migration, which it uses to convert data in the original store to data that it can store in the new store. Once Core Data determines the mapping model, the migration process can start in earnest.

Migrations happen in three steps:

1.  First, Core Data copies over all the objects from one data store to the next.

2.  Next, Core Data connects and relates all the objects according to the relationship mapping.

3.  Finally, enforce any data validations in the destination model. Core Data disables destination model validations during the data copy.

You might ask, "If something goes wrong, what happens to the original source data store?" With nearly all types of Core Data migrations, nothing happens to the original store unless the migration completes without error. Only when a migration is successful, will Core Data remove the original data store.

# Types of migrations

In my own experience, I've found there are a few more migration variants than the simple distinction between lightweight and heavyweight migrations that Apple calls out. Below, I've provided the more subtle variants of migration names, but these names are not official categories by any means. You'll start with the least complex form of migration and end with the most complex form.

## Lightweight migrations

Lightweight migration is Apple's term for the migration with the least amount of work involved on your part. This happens automatically when you use NSPersistentContainer, or you have to set some flags when building your own Core Data stack. There are some limitations on how much you can change the data model, but because of the small amount of work required to enable this option, it's the ideal setting.

## Manual migrations

Manual migrations involve a little more work on your part. You'll need to specify how to map the old set of data onto the new set, but you get the benefit of a more explicit mapping model file to configure. Setting up a mapping model in Xcode is much like setting up a data model, with similar GUI tools and some automation.

## Custom manual migrations

This is level 3 on the migration complexity index. You'll still use a mapping model, but complement that with custom code to specify custom transformation logic on data. Custom entity transformation logic involves creating an NSEntityMigrationPolicy subclass and performing custom transformations there.

## Fully manual migrations

Fully manual migrations are for those times when even specifying custom transformation logic isn't enough to fully migrate data from one model version to another. Custom version detection logic and custom handling of the migration process are necessary. In this chapter, you'll set up a fully manual migration to update data across non-sequential versions, such as jumping from version 1 to 4.

Throughout this chapter, you'll learn about each of these migration types and when to use them. Let's get started!

# Getting started

Included with the resources for this book is a starter project called UnCloudNotes. Find the starter project and open it in Xcode.

Build and run the app in the iPhone simulator. You'll see an empty list of notes:

![](https://github.com/CoderDream/Core-Data-by-Tutorials/blob/master/v6/Chapter06/images/image78.jpg)

Tap the plus (+) button in the top-right corner to add a new note. Add a title (there's default text in the note body to make the process faster) and tap Create to save the new note to the data store. Repeat this a few times so you have some sample data to migrate.

Back in Xcode, open the **UnCloudNotesDatamodel.xcdatamodeld** file to show the entity modeling tool in Xcode. The data model is simple --- just one entity, a Note, with a few attributes.

![](https://github.com/CoderDream/Core-Data-by-Tutorials/blob/master/v6/Chapter06/images/image79.jpg)

You're going to add a new feature to the app: the ability to attach a photo to a note. The data model doesn't have any place to persist this kind of information, so you'll need to add a place in the data model to hold onto the photo. But you already added a few test notes in the app. How can you change the model without breaking the existing notes?

It's time for your first migration!

# A lightweight migration

In Xcode, select the UnCloudNotes data model file if you haven't already. This will show you the Entity Modeler in the main work area. Next, open the Editor menu and select **Add Model Version\...**. Name the new version UnCloudNotesDataModel v2 and ensure UnCloudNotesDataModel is selected in the Based on model field. Xcode will now create a copy of the data model.

```
Note: You can give this file any name you want. The sequential v2, v3, v4, etcetera naming helps you easily tell the versions apart.
```

This step will create a second version of the data model, but you still need to tell Xcode to use the new version as the current model. If you forget this step, selecting the top level **UnCloudNotesDataModel.xcdatamodeld** file will perform any changes you make to the original model file. You can override this behavior by selecting an individual model version, but it's still a good idea to make sure you don't accidentally modify the original file.

In order to perform any migration, you want to keep the original model file as it is, and make changes to an entirely new model file.

In the File Inspector pane on the right, there is a selection menu toward the bottom called Model Version.

Change that selection to match the name of the new data model,

UnCloudNotesDataModel v2.

![](https://github.com/CoderDream/Core-Data-by-Tutorials/blob/master/v6/Chapter06/images/image80.jpg)

Once you've made that change, notice that the little green check mark icon in the project navigator has moved from the previous data model to the v2 data model:

![](https://github.com/CoderDream/Core-Data-by-Tutorials/blob/master/v6/Chapter06/images/image81.jpg)

Core Data will try to first connect the persistent store with the ticked model version when setting up the stack. If a store file was found, and it isn't compatible with this model file, a migration will be triggered. The older version is there to support migration. The current model is the one Core Data will ensure is loaded prior to attaching the rest of the stack for your use.

Make sure you have the v2 data model selected and add an **image** attribute to the Note entity. Set the attribute's name to image and the attribute's type to **Transformable**.

Since this attribute is going to contain the actual binary bits of the image, you'll use a custom NSValueTransformer to convert from binary bits to a UIImage and back again. Just such a transformer has been provided for you in ImageTransformer. In the Data Model Inspector on the right of the screen, look for the Value Transformer field, and enter **ImageTransformer**. Next, in the Module field, choose **Current Product Module**.

![](https://github.com/CoderDream/Core-Data-by-Tutorials/blob/master/v6/Chapter06/images/image82.jpg)

```
Note: When referencing code from your model files, just like in Xib and Storyboard files, you’ll need to specify a module (UnCloudNotes or Current Product Module depending on what your drop down provides) to allow the class loader to find the exact code you want to attach.
```

The new model is now ready for some code! Open **Note.swift** and add the following property below displayIndex:

```swift
@NSManaged var image: UIImage?
```

Build and run the app. You'll see your notes are still magically displayed! It turns out lightweight migrations are enabled by default. This means every time you create a new data model version, and it *can* be auto migrated, it will be. What a time saver!

# Inferred mapping models

It just so happens Core Data can infer a mapping model in many cases when you enable the shouldInferMappingModelAutomatically flag on the NSPersistentStoreDescription. Core Data can automatically look at the differences in two data models and create a mapping model between them.

For entities and attributes that are identical between model versions, this is a straightforward data pass through mapping. For other changes, just follow a few simple rules for Core Data to create a mapping model.

In the new model, changes must fit an obvious migration pattern, such as:

- Deleting entities, attributes or relationships

- Renaming entities, attributes or relationships using the renamingIdentifier

- Adding a new, optional attribute

- Adding a new, required attribute with a default value

- Changing an optional attribute to non-optional and specifying a default value

- Changing a non-optional attribute to optional

- Changing the entity hierarchy

- Adding a new parent entity and moving attributes up or down the hierarchy

- Changing a relationship from to-one to to-many

- Changing a relationship from non-ordered to-many to ordered to-many (and vice versa)

```
Note: Check out Apple’s documentation for more information on how Core Data infers a lightweight migration mapping: https://developer.apple.com/documentation/coredata/using_lightweight_migration.
```

As you see from this list, Core Data can detect, and more importantly, automatically react to, a wide variety of common changes between data models.

As a rule of thumb, all migrations, if necessary, should start as lightweight migrations and only move to more complex mappings when the need arises.

As for the migration from UnCloudNotes to UnCloudNotes v2, the image property has a default value of nil since it's an optional property. This means Core Data can easily migrate the old data store to a new one, since this change follows item 3 in the list of lightweight migration patterns.

## Image attachments 图片附件

Now the data is migrated, you need to update the UI to allow image attachments to new notes. Luckily, most of this work has been done for you. 现在，数据已经迁移，你需要更新界面以允许图片附件添加到新便签中。幸运的是，绝大多数的工作已经在你开始之前完成了。

Open **Main.storyboard** and find the Create Note scene. Underneath, you'll see the Create Note With Images scene that includes the interface to attach an image. 打开 【Main.storyboard】 文件，然后找到创建便签场景。 在场景下方，你将看到创建带图片附件的场景。

The Create Note scene is attached to a navigation controller with a root view controller relationship. Control-drag from the navigation controller to the Create Note With Images scene and select the root view controller relationship segue.创建便签场景是一个附着在根视图控制器的导航控制器。拖拽一个导航控制器到视图中，然后选择根视图控制器作为转场关系。

This will disconnect the old Create Note scene and connect the new, image-powered one instead. 这将使新的连接代替旧的连接。

![](https://github.com/CoderDream/Core-Data-by-Tutorials/blob/master/v6/Chapter06/images/image83.jpg)

Next, open **AttachPhotoViewController.swift** and add the following method to the UIImagePickerControllerDelegate extension: 接下来，打开 【AttachPhotoViewController.swift】 文件，把下面的方法添加到 【UIImagePickerControllerDelegate】 代理的扩展中：

```swift
func imagePickerController(_ picker: UIImagePickerController,
didFinishPickingMediaWithInfo info:
[UIImagePickerController.InfoKey: Any]) {
guard let note = note else { return }
note.image =
info[UIImagePickerController.InfoKey.originalImage] as?
UIImage
_ = navigationController?.popViewController(animated: true)
}
```

This will populate the new image property of the note once the user selects an image from the standard image picker. 这将弹出一个标准的图片选择器，用户选择的图片将用于设置便签的图片属性。

Next, open **CreateNoteViewController.swift** and replace viewDidAppear(\_:) with the following:接下来，打开 【CreateNoteViewController.swift】 ，用下面的代码替换 viewDidAppear(\_:) 方法：

```swift
override func viewDidAppear(_ animated: Bool) {
super.viewDidAppear(animated)
guard let image = note?.image else {
titleField.becomeFirstResponder()
return
}
attachedPhoto.image = image
view.endEditing(true)
}
```

This will display the new image if the user has added one to the note.这样就会显示用户选择的图片到便签中。

Next, open **NotesListViewController.swift** and update tableView(\_:cellForRowAt): with the following:接下来

This will dequeue the correct UITableViewCell subclass based on the note having an image present or not. Finally, open **NoteImageTableViewCell.swift** and add the following to updateNoteInfo(note:):

This will update the UIImageView inside the NoteImageTableViewCell with the image from the note. Build and run, and choose to add a new note:

![](https://github.com/CoderDream/Core-Data-by-Tutorials/blob/master/v6/Chapter06/images/image84.jpg)

Tap the Attach Image button to add an image to the note. Choose an image from your simulated photo library and you'll see it in your new note:

![](https://github.com/CoderDream/Core-Data-by-Tutorials/blob/master/v6/Chapter06/images/image85.jpg)

The app uses the standard UIImagePickerController to add photos as attachments to notes.

If you're using a device, open **AttachPhotoViewController.swift** and set the sourceType attribute on the image picker controller to .camera to take photos with the device camera. The existing code uses the photo album, since there is no camera in the Simulator.

Add a couple of sample notes with photos, since in the next section you'll be using the sample data to move forward with a slightly more complex migration.

Congratulations; you've successfully migrated your data and added a new feature based on the migrated data.

# A manual migration

The next step in the evolution of this data model is to move from attaching a single image to a note to attaching multiple images. The note entity will stay, and you'll need a new entity for an image. Since a note can have many images, there will be a to-many relationship.

Splitting one entity into two isn't exactly on the list of things lightweight migrations can support. It's time to level up to a custom manual migration!

The first step in every migration is to create a new model version. As before, select the **UnCloudNotesDataModel.xcdatamodeld** file and from the Editor menu item, select Add Model Version\.... Name this model UnCloudNotesDataModel v3 and base it on the v2 data model. Set the new model version as the default model using the option in the File Inspector Pane.

Next, you'll add a new entity to the new data model. In the lower-left corner, click the Add Entity button. Rename this entity Attachment. Select the entity and in the Data Model Inspector pane, set the Class Name to Attachment, and the Module to Current Product Module.

![](https://github.com/CoderDream/Core-Data-by-Tutorials/blob/master/v6/Chapter06/images/image86.jpg)

Create two attributes in the Attachment entity. Add a non-optional attribute named image of type Transformable, with the Custom Class transformer field set to ImageTransformer and Module field set to Current Product Module. This is the same as the image attribute you added to the Note entity earlier. Add a second non- optional attribute called dateCreated and make it a Date type.

Next, add a relationship to the Note entity from the Attachment entity. Set the relationship name to note and its destination to Note.

Select the Note entity and delete the image attribute. Finally, create a to-many relationship from the Note entity to the Attachment entity. Leave it marked as *Optional*. Name the relationship attachments, set the destination to Attachment and select the note relationship you just created as the inverse.

![](https://github.com/CoderDream/Core-Data-by-Tutorials/blob/master/v6/Chapter06/images/image87.jpg)

The data model is now ready for migration! While the Core Data model is ready, the code in your app will need some updates to use the changes to the data entities.

Remember, you're not working with the image property on a Note any more, but with multiple attachments.

Create a new file called **Attachment.swift** and replace its contents with the following:

Next, open **Note.swift** and replace the image property with the following:

The rest of your app still depends on an image property, so you'll get a compile error if you try to build the app. Add the following to the Note class below attachments:

This implementation uses a computed property, which gets the image from the latest attachment.

If there are several attachments, latestAttachment will, as its name suggests, grab the latest one and return it.

Next, open **AttachPhotoViewController.swift**. Update it to create a new Attachment object when the user chooses an image. Add the Core Data import to the top of the file:

Next, replace imagePickerController(\_:didFinishPickingMediaWithInfo:)

with:

This implementation creates a new Attachment entity adding the image from the UIImagePickerController as the image property then sets the note property of the Attachment as the current note.

## Mapping models

With lightweight migrations, Core Data can automatically create a mapping model to migrate data from one model version to another when the changes are simple. When the changes aren't as simple, you can manually set up the steps to migrate from one model version to another with a mapping model.

It's important to know that before creating a mapping model, you must complete and finalize your target model.

During the process for creating a new Mapping Model, you'll essentially lock in the source and destination model versions into the Mapping Model file.

This means any changes you make to the actual data model after creating the mapping model will not be seen by the Mapping Model.

Now that you've finished making changes to the v3 data model, you know lightweight migration isn't going to do the job. To create a mapping model, open the File menu in Xcode and select **New ▸ File**.

Navigate to the iOS\\Core Data section and select Mapping Model:

![](https://github.com/CoderDream/Core-Data-by-Tutorials/blob/master/v6/Chapter06/images/image88.jpg)

Click Next, select the v2 data model as the source model and select the v3 data model as the target model.

Name the new file **UnCloudNotesMappingModel\_v2\_to\_v3**. The file naming convention I typically use is the data model name along with the source version and destination version. As an application collects more and more mapping models over time, this file naming convention makes it easier to distinguish between files and the order in which they have changed over time.

Open **UnCloudNotesMappingModel\_v2\_to\_v3.xcmappingmodel**. Luckily, the mapping model doesn't start completely from scratch; Xcode examines the source and target models and infers as much as it can, so you're starting out with a mapping model that consists of the basics.

## Attribute mapping

There are two mappings, one named NoteToNote and another simply named Attachment. NoteToNote describes how to migrate the v2 Note entity to the v3 Note entity.

Select NoteToNote and you'll see two sections: **Attribute Mappings** and

#### Relationship Mappings.

![](https://github.com/CoderDream/Core-Data-by-Tutorials/blob/master/v6/Chapter06/images/image89.jpg)

The attributes mappings here are fairly straightforward. Notice the value expressions with the pattern \$source. \$source is a special token for the mapping model editor, representing a reference to the source instance. Remember, with Core Data, you're not dealing with rows and columns in a database. Instead, you're dealing with objects, their attributes and classes.

In this case, the values for body, dateCreated, displayIndex and title will be transferred directly from the source. Those are the easy cases!

The attachments relationship is new, so Xcode couldn't fill in anything from the source. But, it turns out you'll not be using this particular relationship mapping, so delete this mapping. You'll get to the proper relationship mapping shortly.

Select the Attachment mapping and make sure the Utilities panel on the right is open.

Select the last tab in the Utilities panel to open the Entity Mapping inspector:

![](https://github.com/CoderDream/Core-Data-by-Tutorials/blob/master/v6/Chapter06/images/image90.jpg)

Select Note as the source entity in the drop-down list. Once you select the source entity, Xcode will try to resolve the mappings automatically based on the names of the attributes of the source and destination entities. In this case, Xcode will fill in the dateCreated and image mappings for you:

![](https://github.com/CoderDream/Core-Data-by-Tutorials/blob/master/v6/Chapter06/images/image91.jpg)

Xcode will also rename the entity mapping from Attachment to NoteToAttachment. Xcode is being helpful again; it just needs a small nudge from you to specify the source entity. Since the attribute names match, Xcode will fill in the value

expressions for you. What does it mean to map data from Note entities to Attachment entities? Think of this as saying, "For each Note, make an Attachment and copy the image and dateCreated attributes across."

This mapping will create an Attachment for every Note, but you really only want an Attachment if there is an image attached to the note. Make sure the NoteToAttachment entity mapping is selected and in the inspector, set the Filter Predicate field to **image != nil**. This will ensure the Attachment mapping only occurs when an image is present in the source.

## Relationship mapping

The migration is able to copy the images from Notes to Attachments, but as of yet, there's no relationship linking the Note to the Attachment. The next step to get that behavior is to add a relationship mapping.

In the NoteToAttachment mapping, you'll see a relationship mapping called note. Like the relationship mapping you saw in NoteToNote, the value expression is empty since Xcode doesn't know how to automatically migrate the relationship.

Select the **NoteToAttachment** mapping. Select the note relationship row in the list of relationships so that the Inspector changes to reflect the properties of the relationship mapping. In the Source Fetch field, select **Auto Generate Value Expression**. Enter \$source in the Key Path field and select **NoteToNote** from the Mapping Name field.

![](https://github.com/CoderDream/Core-Data-by-Tutorials/blob/master/v6/Chapter06/images/image92.jpg)

This should generate a value expression that looks like this:

The **FUNCTION** statement resembles the objc\_msgSend syntax; that is, the first argument is the object instance, the second argument is the selector and any further arguments are passed into that method as parameters.

So, the mapping model is calling a method on the \$manager object. The \$manager token is a special reference to the NSMigrationManager object handling the migration process.

Core Data creates the migration manager during the migration. The migration manager keeps track of which source objects are associated with which destination objects. The method destinationInstancesForEntityMappingNamed:sourceInstances: will look up the destination instances for a source object.

The expression on the previous page says "set the note relationship to whatever the

\$source object for this mapping gets migrated to by the NoteToNote mapping," which in this case will be the Note entity in the new data store. You've completed your custom mapping! You now have a mapping that is configured to split a single entity into two and relate the proper data objects together.

## One last thing

Before running this migration, you need to update the Core Data setup code to use this mapping model and not try to infer one on its own.

Open **CoreDataStack.swift** and look for the storeDescription property on to which you set the flags for enabling migrations in the first place. Change the flags to the following:

By setting shouldInferMappingModelAutomatically to false, you've ensured that the persistent store coordinator will now use the new mapping model to migrate the store. Yes, that's all the code you need to change; there is no new code!

When Core Data is told not to infer or generate a mapping model, it will look for the mapping model files in the default or main bundle. The mapping model contains the source and destination versions of the model. Core Data will use that information to determine which mapping model, if any, to use to perform a migration. It really is as simple as changing a single option to use the custom mapping model.

Strictly speaking, setting shouldMigrateStoreAutomatically to true isn't necessary here as true is the value by default. But, let's just say, we're going to need this again later.

Build and run the app. You'll notice not a whole lot has changed on the surface! However, if you still see your notes and images as before, the mapping model worked. Core Data has updated the underlying schema of the SQLite store to reflect the changes in the v3 data model.

# A complex mapping model

The higher-ups have thought of a new feature for UnCloudNotes, so you know what that means. It's time to migrate the data model once again! This time, they've decided that supporting only image attachments isn't enough. They want future versions of the app to support videos, audio files or really add any kind of attachment that makes sense.

You make the decision to have a base entity called Attachment and a subclass called ImageAttachment. This will enable each attachment type to have its own useful information. Images could have attributes for caption, image size, compression level, file size, et cetera. Later, you can add more subclasses for other attachment types.

While new images will grab this information prior to saving, you'll need to extract that information from current images during the migration. You'll need to use either CoreImage or the ImageIO libraries. These are data transformations that Core Data definitely doesn't support out of the box, which makes a custom manual migration the proper tool for the job.

As usual, the first step in any data migration is to select the data model file in Xcode and select **Editor ▸ Add Model Version\...**. This time, create version 4 of the data model called UnCloudNotesDataModel v4. Don't forget to set the current version of the data model to v4 in the Xcode Inspector.

Open the v4 data model and add a new entity named ImageAttachment. Set the class to ImageAttachment, and the module to Current Product Module. Make the following changes to ImageAttachment:

1.  Set the Parent Entity to Attachment.

2.  Add a required String attribute named caption.

3.  Add a required Float attribute named width.

4.  Add a required Float attribute name height.

5.  Add an optional Transformable attribute named image.

6.  Set the ValueTransformer to ImageTransformer, and set the Module value to

Current Product Module.

Next, inside the Attachment entity:

7.  Delete the image attribute.

8.  If a newRelationship has been automatically created, delete it.

![](https://github.com/CoderDream/Core-Data-by-Tutorials/blob/master/v6/Chapter06/images/image93.jpg)

A parent entity is similar to having a parent class, which means ImageAttachment will inherit the attributes of Attachment. When you set up the managed object subclass later, you'll see this inheritance made explicit in the code.

Before you create the custom code for the mapping model, it'll be easier if you create the ImageAttachment source file now. Create a new Swift file called **ImageAttachment** and replace its contents with the following:

Next, open **Attachment.swift** and delete the image property. Since it's been moved to ImageAttachment, and removed from the Attachment entity in the v4 data model, it should be deleted from the code. That should do it for the new data model. Once you've finished, your version 4 data model should look like this:

![](https://github.com/CoderDream/Core-Data-by-Tutorials/blob/master/v6/Chapter06/images/image94.jpg)

## Mapping model

In the Xcode menu, choose **File ▸ New File** and select the **iOS ▸ Core Data ▸ Mapping Model** template. Select version 3 as the source model and version 4 as the target. Name the file **UnCloudNotesMappingModel\_v3\_to\_v4**.

Open the new mapping model in Xcode and you'll see Xcode has again helpfully filled in a few mappings for you.

Starting with the NoteToNote mapping, Xcode has directly copied the source entities from the source store to the target with no conversion or transformation. The default Xcode values for this simple data migration are good to go, as-is!

Select the AttachmentToAttachment mapping. Xcode has also detected some common attributes in the source and target entities and generated mappings. However, you want to convert Attachment entities to ImageAttachment entities. What Xcode has created here will map old Attachment entities to new Attachment entities, which isn't the goal of this migration. Delete this mapping.

Next, select the ImageAttachment mapping. This mapping has no source entity since it's a completely new entity. In the inspector, change the source entity to be Attachment. Now that Xcode knows the source, it will fill in a few of the value expressions for you. Xcode will also rename the mapping to something a little more appropriate, AttachmentToImageAttachment.

![](https://github.com/CoderDream/Core-Data-by-Tutorials/blob/master/v6/Chapter06/images/image95.jpg)

For the remaining, unfilled, attributes, you'll need to write some code. This is where you need image processing and custom code beyond simple FUNCTION expressions! But first, delete those extra mappings, *caption*, *height* and *width*. These values will be computed using a custom migration policy, which happens to be the next section!

## Custom migration policies

To move beyond FUNCTION expressions in the mapping model, you can subclass NSEntityMigrationPolicy directly. This lets you write Swift code to handle the migration, instance by instance, so you can call on any framework or library available to the rest of your app.

Add a new Swift file to the project called **AttachmentToImageAttachmentMigrationPolicyV3toV4.swift** and replace its contents with the following starter code:

This naming convention should look familiar to you; it's noting this is a custom migration policy and is for transforming data from Attachments in model version 3 to ImageAttachments in model version 4.

You'll want to connect this new mapping class to your newly created mapping file before you forget about it. Back in the **v3-to-v4 mapping model file**, select the **AttachmentToImageAttachment** entity mapping. In the Entity Mapping

Inspector, fill in the **Custom Policy** field with the fully namespaced class name you just created (including the module):

- #### UnCloudNotes.AttachmentToImageAttachmentMigrationPolicyV3toV4.

When you press Enter to confirm this change, the type above Custom Policy should change to read Custom.

When Core Data runs this migration, it will create an instance of your custom migration policy when it needs to perform a data migration for that specific set of data. That's your chance to run any custom transformation code to extract image information during migration! Now, it's time to add some custom logic to the custom entity mapping policy.

Open **AttachmentToImageAttachmentMigrationPolicyV3toV4.swift** and add the method to perform the migration:

override func createDestinationInstances( forSource sInstance: NSManagedObject, in mapping: NSEntityMapping,

manager: NSMigrationManager) throws {

// 1

let description = NSEntityDescription.entity( forEntityName: \"ImageAttachment\",

in: manager.destinationContext)

let newAttachment = ImageAttachment( entity: description!,

insertInto: manager.destinationContext)

// 2

func traversePropertyMappings(block: (NSPropertyMapping, String) -\()) throws {

if let attributeMappings = mapping.attributeMappings { for propertyMapping in attributeMappings {

if let destinationName = propertyMapping.name { block(propertyMapping, destinationName)

} else {

// 3

let message =

\"Attribute destination not configured properly\" let userInfo =

\[NSLocalizedFailureReasonErrorKey: message\] throw NSError(domain: errorDomain,

code: 0, userInfo: userInfo)

}

}

} else {

let message = \"No Attribute Mappings found!\"

let userInfo = \[NSLocalizedFailureReasonErrorKey: message\]

throw NSError(domain: errorDomain,

code: 0, userInfo: userInfo)

}

}

// 4

try traversePropertyMappings { propertyMapping, destinationName in

if let valueExpression = propertyMapping.valueExpression { let context: NSMutableDictionary = \[\"source\": sInstance\] guard let destinationValue =

valueExpression.expressionValue(with: sInstance,

context: context) else {

return

}

newAttachment.setValue(destinationValue,

forKey: destinationName)

}

}

// 5

if let image = sInstance.value(forKey: \"image\") as? UIImage { newAttachment.setValue(image.size.width, forKey: \"width\") newAttachment.setValue(image.size.height, forKey: \"height\")

}

// 6

let body =

sInstance.value(forKeyPath: \"note.body\") as? NSString ?? \"\" newAttachment.setValue(body.substring(to: 80),

forKey: \"caption\")

// 7

manager.associate(sourceInstance: sInstance,

withDestinationInstance: newAttachment, for: mapping)

}

This method is an override of the default NSEntityMigrationPolicy implementation. It's what the migration manager uses to create instances of destination entities. An instance of the source object is the first parameter; when overridden, it's up to the developer to create the destination instance and associate it properly to the migration manager.

Here's what's going on, step by step:

1.  First, you create an instance of the new destination object. The migration manager has two Core Data stacks --- one to read from the source and one to write to the destination --- so you need to be sure to use the destination context here.

Now, you might notice that this section isn't using the new fancy short ImageAttachment(context: NSManagedObjectContext) initializer. Well, as it turns out, this migration will simply crash using the new syntax, because it depends on the model having been loaded and finalized, which hasn't happened halfway through a migration.

2.  Next, create a traversePropertyMappings function that performs the task of iterating over the property mappings if they are present in the migration. This function will control the traversal while the next section will perform the operation required for each property mapping.

3.  If, for some reason, the attributeMappings property on the entityMapping object doesn't return any mappings, this means your mappings file has been specified incorrectly. When this happens, the method will throw an error with some helpful information.

4.  Even though it's a custom manual migration, most of the attribute migrations should be performed using the expressions you defined in the mapping model. To do this, use the traversal function from the previous step and apply the value expression to the source instance and set the result to the new destination object.

5.  Next, try to get an instance of the image. If it exists, grab its width and height to populate the data in the new object.

6.  For the caption, simply grab the note's body text and take the first 80 characters.

7.  The migration manager needs to know the connection between the source object, the newly created destination object and the mapping. Failing to call this method at the end of a custom migration will result in missing data in the destination store.

That's it for the custom migration code! Core Data will pick up the mapping model when it detects a v3 data store on launch, and apply it to migrate to the new data model version. Since you added the custom NSEntityMigrationPolicy subclass and linked to it in the mapping model, Core Data will call through to your code automatically.

Finally, its time to go back to the main UI code and update the data model usage to take into account the new ImageAttachment entity. Open **AttachPhotoViewController.swift** and find imagePickerController(\_:didFinishPickingMediaWithInfo:).

Change the line that sets up attachment so it uses ImageAttachment instead:

And while you're here, you should also add a value to the caption attribute. The caption attribute is a required string value, so if an ImageAttachment is created without a value (ie. a nil value), then the save will fail.

Ideally, there would be an extra field from which to enter the value, but add the following line for now:

Next, open **Note.swift** and replace the image property with the following:

Now that all the code changes have been put in place, you need to update the main data model to use v4 as the main data model.

Select UnCloudNotesDataModel.xcdatamodeld in the project navigator. In the Identity pane, under *Model Version* select *UnCloudNotesDataModel v4*.

Build and run the app. The data should migrate properly. Again, your notes will be there, images and all, but you've now future-enabled UnCloudNotes to add video, audio and anything else!

# Migrating non-sequential versions

Thus far, you've walked through a series of data migrations in order. You've migrated the data from version 1 to 2 to 3 to 4, in sequence. Inevitably, in the real world of App Store launches, a user might skip an update and need to go from version 2 to 4, for example. What happens then?

When Core Data performs a migration, its intention is to perform only a single migration. In this hypothetical scenario, Core Data would look for a mapping model that goes from version 2 to 4; if one didn't exist, Core Data would infer one, if you tell it to. Otherwise the migration will fail, and Core Data will report an error when attempting to attach the store to the persistent store coordinator.

How can you handle this scenario so your requested migration succeeds? You could provide multiple mapping models, but as your app grows, you'd need to provide an inordinate number of these: from v1 to v4, v1 to v3, v2 to v4, et cetera. You would spend more time on mapping models than on the app itself!

The solution is to implement a fully custom migration sequence. You know that the migration from version 2 to 3 works; to go from 2 to 4, it will work well if you manually migrate the store from 2 to 3 and from 3 to 4. This step-by-step migration means you'll prevent Core Data from looking for a direct 2 to 4 or even a 1 to 4 migration.

# A self-migrating stack

To begin implementing this solution, you'll want to create a separate migration manager class. The responsibility of this class will be to provide a properly migrated Core Data stack, when asked. This class will have a stack property and will return an instance of CoreDataStack, as UnCloudNotes uses throughout, which has run through all the migrations necessary to be useful for the app.

First, create a new Swift file called DataMigrationManager. Open the file and replace its contents with the following:

You'll notice that we're going to start this off looking like the current CoreDataStack initializer. That is intended to make this next step a little easier to understand.

Next, open **NotesListViewController.swift** and replace the stack lazy initialization code, as shown below:

With:

You'll use the lazy attribute to guarantee the stack is only initialized once. Second, initialization is actually handled by the DataMigrationManager, so the stack used will be the one returned from the migration manager. As mentioned, the signature of the new DataMigrationManager initializer is similar to the CoreDataStack.

That's because you've got a large bit of migration code coming up, and its a good idea to separate the responsibility of migration from the responsibility of saving data.

Now to the harder part: How do you figure out if the store needs migrations? And if it does, how do you figure out where to start? In order to do a fully custom migration, you're going to need a little bit of support. First, finding out whether models match or not is not obvious. You'll also need a way to check a persistent store file for compatibility with a model. Let's get started with all the support functions first!

At the bottom of **DataMigrationManager.swift**, add an extension on

NSManagedObjectModel:

The first method returns all model versions for a given name. The second method returns a specific instance of NSManagedObjectModel named UnCloudNotesDataModel. Usually, Core Data will give you the most recent data model version, but this method will let you dig inside for a specific version.

To use this method, add the following method inside the NSManagedObjectModel

class extension:

This method returns the first version of the data model. That takes care of getting the model, but what about checking the version of a model? Add the following property to the class extension:

The comparison operator for NSManagedObjectModel isn't very helpful for the purpose of properly checking model equality. To get the == comparison to work on

two NSManagedObjectModel objects, add the following operator function to the file. You'll need to add this outside of the class extension, right in the global scope:

The idea here is simple: two NSManagedObjectModel objects are identical if they have the same collection of entities, with the same version hashes.

Now that everything is set up, you can repeat the version and isVersion pattern for the next 3 versions. Go ahead and add the following methods for versions 2 to 4 to the class extension:

Now that you have a way to compare model versions, you'll need a way to check that a particular persistent store is compatible with a model version. Add these two helper methods to the DataMigrationManager class:

The first method is a simple convenience wrapper to determine whether the persistent store is compatible with a given model. The second method helps by safely retrieving the metadata for the store.

Next, add the following computed properties to the DataMigrationManager class:

These properties allow you to access the current store URL and model. As it turns out, there is no method in the CoreData API to ask a store for its model version. Instead, the easiest solution is brute force. Since you've already created helper

methods to check if a store is compatible with a particular model, you'll simply need to iterate through all the available models until you find one that works with the store.

Next, you need your migration manager to remember the current model version. To do this, you'll first create a general use method for getting models from a bundle, then you'll simply use that general purpose method to look up the model.

First, add the following method to the NSManagedObjectModel class extension:

This handy method is used to initialize a managed objet model using the top level folder. Core Data will look for the current model version automatically and load that model into an NSManagedObjectModel for use. It's important to note that this method will only work with with Core Data models that have been versioned.

Next, add a property to the DataMigrationManager class, as follows:

The currentModel property is lazy, so it loads only once since it should return the same thing every time. The .model is the shorthand way of calling the just-added- function that will look up the model from the top level momd folder.

Of course, if the model you have isn't the current model, that's the time to run the migration! Add the following starter method to the DataMigrationManager class (which you'll fill in later):

Next, replace the stack property definition you added earlier with the following:

In the end, the computed property will return a CoreDataStack instance. If the migration flag is set, then check if the store specified in the initialization is compatible with what Core Data determines to be the current version of the data model. If the store can't be loaded with the current model, it needs to be migrated. Otherwise, you can use a stack object with whatever version the model is currently set.

You now have a self-migrating Core Data stack that can always be guaranteed to be up to date with the latest model version! Build the project to make sure everything compiles. The next step is to add the custom migration logic.

## The self-migrating stack

Now it's time to start building out the migration logic. Add the following method to the DataMigrationManager class:

This method does all the heavy lifting. If you need to do a lightweight migration, you can pass nil or simply skip the final parameter.

Here's what's going on, step by step:

1.  First, you create an instance of the migration manager.

2.  If a mapping model was passed in to the method, use that. Otherwise, create an inferred mapping model.

3.  Since migrations will create a second data store and migrate data, instance-by- instance, from the original to the new file, the destination URL must be a different file. Now, the example code in this section will create a destinationURL that is the same folder as the original and a file concatenated with "\~1". The destination URL can be in a temp folder or anywhere your app has access to write files.

4.  Here's where you put the migration manager to work! You've already set it up with the source and destination models, so you simply need to add the mapping model and the two URLs to the mix.

5.  Given the result, you can print a success or error message to the console. In the success case, you perform a bit of cleanup, too. In this case, it's enough to remove the old store and replace it with the new store.

Now it's simply a matter of calling that method with the right parameters. Remember your empty implementation of performMigration? It's time to fill that in.

Add the following lines to that method:

This code will only check that the current model is the most recent version of the model. This code bails out and kills the app if the current model is anything other than version 4. This is a little extreme --- in your own apps, you might want to continue the migration anyway --- but doing it this way will definitely remind you to think about migrations if you ever add another data model version to your app!

Thankfully, even though this is the first check in the performMigration method, it should never be run as the next section stops after the last available migration has been applied.

The performMigration method can be improved to handle all known model versions. To do this, add the following below the previously added if-statement:

The steps are similar, no matter which version you start from:

- Lightweight migrations use simple flags to 1) enable migrations, and 2) infer the mapping model. Since the migrateStoreAt method will infer a mapping model if one is missing, you've successfully replaced that functionality. By running performMigration, you've already enabled migrations.

- Set the destination model to the correct model version. Remember, you're only going "up" one version at a time, so from 1 to 2 and from 2 to 3.

- For version 2 and above, also load the mapping model.

- Finally, call migrateStoreAt(URL:fromModel:toModel:mappingModel:), which you wrote at the start of this section.

What's nice about this solution is that the DataMigrationManager class, despite all the comparison support helper functions, is essentially using the mapping models and code that was already defined for each migration.

This solution is manually applying each migration in sequence rather than letting Core Data try to do things automatically.

# Testing sequential migrations

Testing this type of migration can be a little complicated, since you need to go back in time and run previous versions of the app to generate data to migrate. If you saved copies of the app project along the way, great!

Otherwise, you'll find previous versions of the project in the resources bundled with the book.

First, make sure you make a copy of the project as it is right now --- that's the final project!

Here are the general steps you'll need to take to test each migration:

1.  Delete the app from the Simulator to clear out the data store.

2.  Open version 2 of the app (so you can at least see some pictures!), and build and run.

3.  Create some test notes.

4.  Quit the app from Xcode and close the project.

5.  Open the final version of the app, and build and run.

At this point, you should see some console output with the migration status. Note the migration will happen prior to the app presenting onscreen.

![](https://github.com/CoderDream/Core-Data-by-Tutorials/blob/master/v6/Chapter06/images/image96.jpg)

You now have an app that will successfully migrate between any combinations of old data versions to the latest version.

# Key points

- A migration is necessary when you need to make changes to the data model.

- Use the simplest migration method possible.

- Lightweight migration is Apple's term for the migration with the least amount of work involved on your part.

- Heavyweight migrations, as described by Apple, can incorporate several different types of custom migration.

- Custom migrations let you create a mapping model to direct Core Data to make more complex changes that lightweight can't do automatically.

- Once a mapping model has been created, do not change the target model.

- Custom manual migrations go one step further from a mapping model and let you change the model from code.

- Fully manual migrations let your app migrate sequentially from one version to the next preventing issues if a user skips updating their device to a version in between.

- Migration testing is tricky because it is dependent on the data from the source store. Make sure to test several scenarios before releasing your app to the App Store.