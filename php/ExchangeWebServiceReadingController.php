<?php
namespace console\controllers;

use common\models\User;
use frontend\models\LogEntry;
use frontend\modules\sq\controllers\RequestController;
use frontend\modules\sq\SQModule;
use garethp\ews\API\ExchangeWebServices;
use Yii;
use yii\console\Controller;
use garethp\ews\MailAPI;
use garethp\ews\API\Enumeration\IndexBasePointType;

class ExchangeWebServiceReadingController extends Controller
{
    private static $exchangeServerAddress = 'outlook.office365.com';
    private static $exchangeServerVersion = ExchangeWebServices::VERSION_2016;

    public function init() {
        parent::init();
        \Yii::$app->user->setIdentity(User::findOne(['id' => 3652])); // Robot Consolidator
    }

    private static $folder = '';

    public function actionReadEmails() {
        putenv('HTTP_PROXY=');
        putenv('HTTPS_PROXY=');

        $timeStart = microtime(true);
        $logMessage = 'Email reading: <br>';
        $folder = '';

        $api = MailAPI::withUsernameAndPassword(
            $this::$exchangeServerAddress,
            Yii::$app->params['testUser']['usermail'],
            Yii::$app->params['testUser']['password'],
            [
                'primarySmtpEmailAddress' => $folder,
                'version' => $this::$exchangeServerVersion,
            ]
        );

        $data = $api->getMailItems(
            null,
            [
                'IndexedPageItemView' => [
                    'BasePoint' => IndexBasePointType::BEGINNING,
                    'Offset' => 0,
                    'MaxEntriesReturned' => 1000,
                ]
            ]
        );

        $attachments = [];
        $todayDate = date('Y-m-d');

        foreach ($data as $item) {
            $date = date('Y-m-d', strtotime($item->getDateTimeSent()));

            if ($date == $todayDate && $item->getAttachments() != null) {
                $attachment = $item->getAttachments()->getFileAttachment();
                $file = $api->getAttachment($attachment[0]->getAttachmentId());
                $attachments[] = $file;

                if (!empty($attachments)) {
                    $logMessage .= RequestController::importRequests($attachments) ? "Success!" : "Fail!";
                }
            }
        }

        $timeEnd = microtime(true);
        $timePassed = round($timeEnd - $timeStart, 3);
        $logMessage .= "<strong>Time:</strong> {$timePassed}s.";

        $logEntry = new LogEntry();
        $logEntry->module_id = SQModule::MODULE_ID;
        $logEntry->category = 'pega import';
        $logEntry->message = $logMessage;

        echo $logMessage;
        $logEntry->save();
    }
}
