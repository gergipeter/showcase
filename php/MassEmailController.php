<?php

namespace console\controllers;

use yii\console\Controller;
use \Yii;
use common\models\DocumentTemplate;
use frontend\models\LogEntry;
use frontend\modules\po\POModule;
use common\models\User;
use common\models\UserSCD;
use frontend\modules\po\models\PoUserSettings;


class MassEmailController extends Controller {
    public function init() {
        parent::init();
        \Yii::$app->user->setIdentity(User::findOne(['id' => 3652])); // Robot Consolidator
    }

    public function actionMassEmailSend()
    {
    	/**
    	 * 1st: select "new items", team / period
    	 * 2nd: send out the emails
    	 * 3rd: set status from "created" to "in progress"
    	 * 3rd a): set status from "created" to "in progress" in po.record also where po_number is not in po.request(po_number)
    	 * 4th: select records where status is "in progress" and "is_reminder_sent" is null and "created_at" + 2 weeks > today
    	 * 5th: send out the reminder emails
    	 * 6th: set "is_reminder_sent" to yes, where status is "in progress"
    	 */
    	
    	$connection = Yii::$app->db;
    	$timeStart = microtime(true);
    	
    	echo "Mass Email Sending";
    	echo "\n------------------";
    	
    	$commandSelect = $connection->createCommand("
    			select full_name, email, t.name as team, period, new_items,  CONVERT(date, dbo.[AddWorkDays](10,getdate())) as target
				from dbo.[user] u
				left join indigo.team t on u.team_id = t.id
				left join dbo.auth_assignment a on a.user_id = u.id
				left join
				(select ro.team, rq.period, count(*) as new_items
				from po.request rq
				left join po.record_view ro on rq.po_number = ro.po_number and rq.period = ro.period
				where rq.status_id = 1
				group by ro.team, rq.period) sub on t.name = sub.team
				where item_name like '%POModule%' and new_items > 0");

    	$resultMassEmail = $commandSelect->queryAll();
    	$sizeOfResultMassEmail = sizeof($resultMassEmail);
    	$usedTemplateMassEmail = DocumentTemplate::findOne(['category' => 1,'module_id' => 15])->title;
    	$logMessage = "<b>$sizeOfResultMassEmail</b> emails are sent.<br>";
    	$logMessage .= "<b>Used Template: </b>" . $usedTemplateMassEmail . "<br>";
    
		
    	if ($sizeOfResultMassEmail > 0) {
    		for ($i = 0; $i < $sizeOfResultMassEmail; $i++) {
    			$name = $resultMassEmail[$i]['full_name'];
    			$team = $resultMassEmail[$i]['team'];
    			$emailAddress = $resultMassEmail[$i]['email'];
    			$period = $resultMassEmail[$i]['period'];
    			$new_items = $resultMassEmail[$i]['new_items'];
    			$target = $resultMassEmail[$i]['target'];
    			$signature = PoUserSettings::findOne(['user_id' => 9, 'module_id' => 15, 'name' => 'signature'])->value;    			
    			
    			$substitution = [
    					'{SIGNATURE}' => (isset($signature)) ? $signature : '',
    					'{AGENT_NAME}' => $name,
    					'{TARGET_DATE}' => $target,
    					'{TEAM}' => $team,
    					'{PERIOD}' => $period,
    					'{NEW_ITEMS}' => $new_items
    			];
    		
				/**
				 * Email template: New POs was uploaded for Quality check
				 */
    			$email = DocumentTemplate::findOne(['category' => 1,'module_id' => 15]);
    			$emailTemplate = str_replace(array_keys($substitution), array_values($substitution), $email->template);
    			$emailTitle = str_replace(array_keys($substitution), array_values($substitution), $email->title);

				echo "\nSending to: " . $emailAddress . "\n";
                $logMessage .= "\nSending to: " . $emailAddress . "\n";
				try
				{
					$resultSend = \Yii::$app->mailer->compose('layouts/outlook',[
							'content'=> $emailTemplate,
							'title'=> $emailTitle ])
							->setFrom('')
							->setTo($emailAddress)
							->setSubject($emailTitle)
							->send();
					if ($resultSend){
						echo "\n     OK\n";
					}
				} catch(\Swift_SwiftException $exception)
				{
					echo  'Cant sent mail due to the following exception: '.print_r($exception->getMessage());
					$logMessage .= 'Cant sent mail due to the following exception: '.print_r($exception->getMessage());
				}
				
				
				if (\Yii::$app->mailer->getTransport()->isStarted()) {
					\Yii::$app->mailer->getTransport()->stop();
				}
    		}
    		
    		echo "\nMass Emails are successfully sent";
    		echo "\n---------------------------------";
    		 
    		echo "\nSet status from created to in progress";
    		echo "\n--------------------------------------";
    		
    		$commandSetMassEmail = $connection->createCommand("UPDATE po.request SET status_id = 3 WHERE status_id = 1");
    		if ($rowsAffected = $commandSetMassEmail->execute()) {
    			$logMessage .= "<b>$rowsAffected request(s) </b>status has been set to <b>in progress</b><br>";
    			echo "\n$rowsAffected row(s) affected.";
    			echo "\n------------------------------";
    		}
    		
    	} else {
    		echo "\n0 mass email was sent";
    		echo "\n--------------------------";
    	}

    	echo "\nReminder Emails Sending";
    	echo "\n-----------------------";
    	
    	$commandSelectReminder = $connection->createCommand("
    			select full_name, email, t.name as team, period, new_items
				from dbo.[user] u
				left join indigo.team t on u.team_id = t.id
				left join dbo.auth_assignment a on a.user_id = u.id
				left join
				(select ro.team, rq.period, count(*) as new_items
				from po.request rq
				left join po.record_view ro on rq.po_number = ro.po_number and rq.period = ro.period
				where rq.status_id = 3
				and (rq.is_reminder_sent = 0 or rq.is_reminder_sent is null)
				and dbo.[AddWorkDays](10,rq.created_at) < getdate()
				group by ro.team, rq.period) sub on t.name = sub.team
				where item_name like '%POModule%' and new_items > 0 ");

    	$resultReminder = $commandSelectReminder->queryAll();
    	$sizeOfResultReminder = sizeof($resultReminder);
    	$usedTemplateReminder = DocumentTemplate::findOne(['category' => 2,'module_id' => 15])->title;
    	$logMessage .= "<b>$sizeOfResultReminder emails</b> are sent.<br>";
    	$logMessage .= "<b>Used Template: </b>" . $usedTemplateReminder . "<br>";
    	
    	if ($sizeOfResultReminder > 0) {
    		for ($i = 0; $i < $sizeOfResultReminder; $i++) {
    			$name = $resultReminder[$i]['full_name'];
    			$team = $resultReminder[$i]['team'];
    			$emailAddress = $resultReminder[$i]['email'];
    			$period = $resultReminder[$i]['period'];
    			$new_items = $resultReminder[$i]['new_items'];
    			$signature = PoUserSettings::findOne(['user_id' => 9, 'module_id' => 15, 'name' => 'signature'])->value;
    			
    			$substitution = [
    					'{SIGNATURE}' => (isset($signature)) ? $signature : '',
    					'{AGENT_NAME}' => $name,
    					'{TEAM}' => $team,
    					'{PERIOD}' => $period,
    					'{NEW_ITEMS}' => $new_items
    			];
    			 
    			$email = DocumentTemplate::findOne(['category' => 2,'module_id' => 15]);
    			$emailTemplate = str_replace(array_keys($substitution), array_values($substitution), $email->template);
    			$emailTitle = str_replace(array_keys($substitution), array_values($substitution), $email->title);
    			echo "\nSending to: " . $emailAddress . "\n";
                $logMessage .= "\nSending to: " . $emailAddress . "\n";

                try
				{
					$resultSend = \Yii::$app->mailer->compose('layouts/outlook',[
    					'content'=> $emailTemplate,
    					'title'=> $emailTitle ])
    					->setFrom('')
    					->setTo($emailAddress)
    					->setSubject($emailTitle)
    					->send();
					if ($resultSend){
						echo "\n     OK\n";
					}
				} catch(\Swift_SwiftException $exception)
					{
						echo 'Cant sent mail due to the following exception: '.print_r($exception->getMessage());
                        $logMessage .= 'Cant sent mail due to the following exception: '.print_r($exception->getMessage());
					}
					if (\Yii::$app->mailer->getTransport()->isStarted()) {
						\Yii::$app->mailer->getTransport()->stop();
					}
    		}
    		 
    		echo "\nReminder Emails are successfully sent";
    		echo "\n-------------------------------------";
    		 
    		echo "\nSet is_reminder_sent to yes, where status in progress";
    		echo "\n-----------------------------------------------------";
    		
    		$commandSetReminder = $connection->createCommand("UPDATE po.request SET is_reminder_sent = 1 WHERE status_id = 3");
    		if ($rowsAffected = $commandSetReminder->execute()) {
    			$logMessage .= "<b>$rowsAffected request(s)</b> is_reminder_sent has been set to <b>Yes</b><br>";
    			echo "\n$rowsAffected row(s) affected.";
    			echo "\n------------------------------";
    		}
    	} else {
    		echo "\n0 reminder email was sent";
    		echo "\n--------------------------";
    	}

    	$timeEnd = microtime(true);
    	$timePassed = round($timeEnd - $timeStart, 3);
    	$logMessage.="<strong>Time:</strong> " . $timePassed . 's.';
    	$logEntry = new LogEntry();
    	$logEntry->module_id = POModule::MODULE_ID;
    	$logEntry->category = 'mass mail';
    	$logEntry->message = $logMessage;
    	$logEntry->save();
    }

}
