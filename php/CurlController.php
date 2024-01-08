<?php

namespace console\controllers;

use common\models\Supplier;
use frontend\models\LogEntry;
use yii\console\Controller;
use yii\console\ExitCode;
use common\models\User;
use Yii;

class CurlController extends Controller {

    public static $MAILSERVER_TIMEOUT = false;

    public function init() {
        parent::init();
        Yii::$app->user->setIdentity(User::findOne(['id' => 3652])); // Robot Consolidator
    }

    /**
     * Function to check the GXS (OpenText) API for updates in the last $days
     * @param int $days the number of days for which updates should be queried
     * @return int ExitCode
     */
    public function actionGxs($days = 1)
    {
        $logMessage = "Checking the GXS API for changes in the last {$days} days\n<br>-------------";

        $url = '';
        $apiKey = '';
        $source = '';
        $email = '';
        $timestamp = gmdate("Y-m-d\TH:i:s\Z"); // UTC timezone
        $secret = '';
        $hash = sha1("{$email}{$timestamp}{$secret}");
        $completeUrl = "{$url}?apiKey={$apiKey}&source={$source}&email={$email}&timestamp={$timestamp}&hash={$hash}";

        $ch = curl_init();
        curl_setopt($ch, CURLOPT_HEADER, 0);
        curl_setopt($ch, CURLOPT_RETURNTRANSFER, 1);
        curl_setopt($ch, CURLOPT_URL, $completeUrl);
        curl_setopt($ch, CURLOPT_PROXY, "");
        curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);

        $datetime = date('m/d/Y H:i:s', strtotime("-{$days} days", time()));
        $xmlPost = "<Search>
                        <Group conditions_operand='all'>
                            <Condition model='Company'>
                                <Attribute>updated_at</Attribute>
                                <Operator>on_or_after</Operator>
                                <Values>
                                    <Value>{$datetime}</Value>
                                </Values>
                            </Condition>
                        </Group>
                    </Search>";

        $logMessage .= "\n<br>POST:\n<br>{$xmlPost}\n<br>-------------\n<br>";
        
        curl_setopt($ch, CURLOPT_POST, 1);
        curl_setopt($ch, CURLOPT_POSTFIELDS, $xmlPost);
        $content = curl_exec($ch);
        
        $logMessage .= "\nResponse:\n{$content}";
        curl_close($ch);

        if ($content != "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<companies>\n</companies>\n") {
            $companies = simplexml_load_string($content);
            if (isset($companies->Company)) {
                foreach ($companies->Company as $company) {
                    $logMessage .= Supplier::processOpentextXmlOutput($company);
                }
            }
        } else {
            $logMessage .= "\n<br>-------------\n<br>Apparently no changes...";
        }

        $logEntry = new LogEntry();
        $logEntry->module_id = '';
        $logEntry->category = 'GXS API Query';
        $logEntry->message = $logMessage;
        $logEntry->save();

        echo $logMessage;
        return ExitCode::OK;
    }
}
