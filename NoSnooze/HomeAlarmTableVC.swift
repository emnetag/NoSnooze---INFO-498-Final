//
//  HomeAlarmTableVC.swift
//  NoSnooze
//
//  Created by Sanjay Sagar on 12/2/15.
//  Copyright © 2015 emnetg. All rights reserved.
//

import UIKit
import Firebase
import FirebaseUI

class HomeAlarmTableVC: UITableViewController {
    
    var alarms : [Alarm] = []
    var currentUser: User!
    
    var rootRef: Firebase!
    
    var alarmsRef: Firebase!
    
    var invitesRef: Firebase!
    
    var myInvitesRef: Firebase!
    
    var usersRef: Firebase!
    
    var alarmHandle: UInt!
    
    var keys: [String]!
    
    var timer2:[(name: NSTimer, value: Alarm)] = []
    var timer = NSTimer()
    var timeInterval:NSTimeInterval = 0.0
    var timeCount:NSTimeInterval =  0.0
    @IBAction func unwindToAlarmHome(segue: UIStoryboardSegue) {
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        rootRef = Firebase(url: "https://nosnooze.firebaseio.com/")
        usersRef = Firebase(url: "https://nosnooze.firebaseio.com/users")
        alarmsRef = Firebase(url: "https://nosnooze.firebaseio.com/alarms")
        invitesRef = Firebase(url: "https://nosnooze.firebaseio.com/invites")
        self.navigationItem.leftBarButtonItem = self.editButtonItem()
    }
    
    func timeString(time:NSTimeInterval) -> String {
        let minutes = Int(time) / 60
        //let seconds = Int(time) % 60
        let seconds = time - Double(minutes) * 60
        let secondsFraction = seconds - Double(Int(seconds))
        return String(format:"%02i:%02i.%01i",minutes,Int(seconds),Int(secondsFraction * 10.0))
    }
    
    func timerDidEnd(timer:NSTimer){
        timeCount = timeCount - timeInterval
       // NSLog("TIMER: \(timeCount)")
        if timeCount <= 0 {
            //timer2.
            let sb = UIStoryboard(name: "AlarmActive", bundle: nil)
            let VC = sb.instantiateInitialViewController() as UIViewController!
            self.presentViewController(VC, animated: true, completion: nil)
            timer.invalidate()
        }
    }
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        //ANYTHING THAT REQUIRES USERID HAS TO OCCUR INSIDE
        //THE BLOCK BECAUSE THATS HOW ASYNC WORKS
        rootRef.observeAuthEventWithBlock { (authData) -> Void in
            if authData != nil {
                print("User is logged in")
                self.currentUser = User(authData: authData)
                
                //myInvitesRef = /invites/currentUser.uid!
                self.myInvitesRef = self.invitesRef.childByAppendingPath(self.currentUser.uid!)
                
                //myAlarmsRef = /users/userID/alarms
                let myAlarmsRef = self.usersRef
                    .childByAppendingPath(authData.uid!)
                    .childByAppendingPath("alarms")
                
                self.listenForAlarms(myAlarmsRef)
                print("But this will execute before I get anything back...")
            } else {
                print("Auth Data is nil")
            }
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        alarmHandle = self.alarmsRef.observeEventType(.ChildAdded, withBlock: { snapshot in
            let alarmKey = snapshot.key
            self.alarms = [Alarm]()
            //This is picking up additional alarms
            /*self.alarmsRef.childByAppendingPath(alarmKey).observeSingleEventOfType(.Value, withBlock: {snapshot in
                let newAlarm = Alarm(snapshot: snapshot)
                self.alarms.append(newAlarm)
                self.tableView.reloadData()
            }) */
            var invite: Invite?
            self.myInvitesRef.observeSingleEventOfType(.ChildAdded, withBlock: { inviteSnap in
                
                if inviteSnap.hasChildren() {
                    
                    invite = Invite(snapshot: inviteSnap)
                    print("I have been invited to \(invite!.alarmID!)")
                    
                    let tempRef = self.alarmsRef.childByAppendingPath(invite!.alarmID!)
                    
                    tempRef.observeSingleEventOfType(.Value, withBlock: {alarmSnap in
                        
                        let alarm = Alarm(snapshot: alarmSnap)
                        print(alarm.addedByUser!)
                        
                        //show Alert Controller
                        //self.showAlertForAlarm(alarm, alarmID: invite!.alarmID!, inviteID: invite!.inviteID!)
                        
                    })
                } else {
                    print("No invites for now")
                }
            })
        })
        NSLog("HUE HUE HUE HUE HUE \(alarms.count)")
        timer2.removeAll()
        for alarm1 in self.alarms {
            if(alarm1.alarmTime.timeIntervalSinceNow < 86400 && alarm1.alarmTime.timeIntervalSinceNow > 0) {
                NSLog("This is the alarm time for \(alarm1.name): \(alarm1.alarmTime.timeIntervalSinceNow)")
                var timer3:NSTimer = timer
                timeInterval = 0.05
                timeCount = alarm1.alarmTime.timeIntervalSinceNow
                timer3 = NSTimer.scheduledTimerWithTimeInterval(timeInterval,
                    target: self,
                    selector: "timerDidEnd:",
                    userInfo: "this",
                    repeats: true) //repeating timer in the second iteration
                timer2.append((name: timer3, value: alarm1))
                //NSLog("\(timer2.description)")
                
            }
        }
        
    }
    
    
    override func viewDidDisappear(animated: Bool) {
            super.viewDidDisappear(animated)
            rootRef.removeAllObservers()
            usersRef.removeAllObservers()
            alarmsRef.removeAllObservers()
            invitesRef.removeAllObservers()
            if self.myInvitesRef != nil {
                self.myInvitesRef.removeAllObservers()
            }
        }
    
    //using .Value and iterating through all alarms 
    //seems to be the only way to update the view
    func listenForAlarms(ref: Firebase) {
        print("ref parent is \(ref.parent!.key!)")
        ref.observeEventType(.Value, withBlock: { (snapshot) -> Void in
            print("Snapshot value is \(snapshot.value)")
            var newAlarms = [Alarm]()
            if snapshot.hasChildren() {
                for item in snapshot.children {
                    let alarm = Alarm(snapshot: item as! FDataSnapshot)
                    newAlarms.append(alarm)
                }
            }
            self.alarms = newAlarms
            self.tableView.reloadData()
        })
    }
    
//    func showAlertForAlarm(alarm: Alarm, alarmID: String, inviteID: String) {
//        print("Showing alert...")
//        
//        self.usersRef.childByAppendingPath(alarm.addedByUser!).observeSingleEventOfType(.Value, withBlock: {userSnap in
//            let userName = userSnap.value["displayName"] as! String
//            
//            let inviteMessage = "\(userName) invited you to their alarm. Would you like to join?"
//            
//            let alertController = UIAlertController(title: "Alarm Invitation", message: inviteMessage, preferredStyle: .Alert)
//
//            // User rejected alarm
//            alertController.addAction(UIAlertAction(title: "Nope", style: .Cancel, handler: {(alert: UIAlertAction!) in
//                print("Invite was declined")
////                self.invitesRef.childByAppendingPath(inviteID).removeValue()
//            }))
//            
//            // User accepts alarm
//            alertController.addAction(UIAlertAction(title: "Okay", style: .Default, handler: {(alert: UIAlertAction!) in
//                print("Invite was acccepted")
//                
//                // Alarm is saved to /users/userid/alarms/alarmid
////                self.myAlarmsRef.childByAppendingPath(alarmID).setValue(alarm.toAnyObject())
//                
//                //Removte invite for user
//                self.invitesRef.childByAppendingPath(inviteID).removeValue()
//            }))
//            
//            self.presentViewController(alertController, animated: true, completion: nil)
//        })
//    }
    
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.alarms.count
    }
    
    
    // Override to support editing the table view.
    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            // Delete the row from the data source
            let alarmKey = alarms[indexPath.row].ref!.key!
            alarms[indexPath.row].ref!.removeValue()
            
            // Delete from /alarms/alarmID as well
            self.alarmsRef.childByAppendingPath(alarmKey).removeValue()
            
            alarms.removeAtIndex(indexPath.row)

            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Left)
            
            tableView.reloadData()
        }
    }
    
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool
    {
        return true
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("AlarmCell", forIndexPath: indexPath) as! AlarmTableViewCell
        
        
        //format cell here
        var currentAlarm = self.alarms[indexPath.row]
        //var s = NSTimer()
       // timer.append(name: currentAlarm, value: s)
       // NSLog("HELLO 2 ALL \(self.alarms[0].dateFormatter.description)")
        // NSLog("HELLO 3 ALL \(self.alarms[0].alarmTime.timeIntervalSinceNow)")
        currentAlarm.toDisplayFormat()
        cell.AlarmText.text = "\(currentAlarm.alarmString)"
        cell.CutoffTime.text = "Snooze Time: \(currentAlarm.cutoffString)"
        
        let text: NSString = "\(currentAlarm.name), Snooze Time: \(currentAlarm.cutoffString)"
        let attributedText: NSMutableAttributedString = NSMutableAttributedString(string: text as String)
        
        attributedText.addAttributes([NSFontAttributeName: UIFont.boldSystemFontOfSize(15)], range: NSRange(location: 0, length: (currentAlarm.name! as NSString).length))

        cell.CutoffTime.attributedText = attributedText
        return cell
    }
}