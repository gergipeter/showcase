<?php

namespace console\controllers;

use yii\console\Controller;
use Yii;
use frontend\models\LogEntry;
use common\models\DocumentTemplate;
use common\models\User;
use yii\console\ExitCode;

class GdprController extends Controller {

    public function init() {
        parent::init();
        Yii::$app->user->setIdentity(User::findOne(['id' => 3652])); // Robot Consolidator
    }

    public function actionAnonymize() {
        $timeStart = microtime(true);
        ini_set('memory_limit', '8192M');

        echo "Anonymize user data in dbo.[user] table\n---------------------------------------";

        $connection = Yii::$app->db;

        $commandSelectUserTable = $connection->createCommand("
            SELECT
                is_anonymized,
                email,
                full_name,
                gid,
                login,
                department,
                position,
                org_unit,
                location,
                country,
                are,
                phone,
                mobile,
                department_long
            FROM dbo.[user]
            WHERE id IN (
                SELECT created_by
                FROM dbo.logentry_view
                GROUP BY created_by
                HAVING MAX(created_at) <= DATEADD(year, -1, GETDATE()) AND is_anonymized = 0
            )");

        $resultSelectUserTable = $commandSelectUserTable->queryAll();
        $sizeOfResultSelectUserTable = sizeof($resultSelectUserTable);

        if ($sizeOfResultSelectUserTable != 0) {
            $commandUpdateUserTable = $connection->createCommand("
                UPDATE dbo.[user] SET
                    is_anonymized = 1,
                    email = CONCAT('DELETED_', id),
                    full_name = CONCAT('DELETED_', id),
                    gid = CONCAT('DELETED_', id),
                    login = CONCAT('DELETED_', id),
                    department = CONCAT('DELETED_', id),
                    position = CONCAT('DELETED_', id),
                    org_unit = CONCAT('DELETED_', id),
                    location = CONCAT('DELETED_', id),
                    country = CONCAT('DELETED_', id),
                    are = CONCAT('DELETED_', id),
                    phone = CONCAT('DELETED_', id),
                    mobile = CONCAT('DELETED_', id),
                    department_long = CONCAT('DELETED_', id)
                WHERE id IN (
                    SELECT created_by
                    FROM dbo.logentry_view
                    GROUP BY created_by
                    HAVING MAX(created_at) <= DATEADD(year, -1, GETDATE())
                ) ");

            $commandUpdateMailTable = $connection->createCommand("
                UPDATE dbo.[mail] SET
                    [from] = '',
                    [to] = '',
                    [subject] = '',
                    [cc] = '',
                    [bcc] = '',
                    [message] = ''
                WHERE created_by IN (
                    SELECT created_by
                    FROM dbo.logentry_view
                    GROUP BY created_by
                    HAVING MAX(created_at) <= DATEADD(year, -1, GETDATE())
                )");

            $resultUpdateUserTable = $commandUpdateUserTable->execute();
            $resultUpdateMailTable = $commandUpdateMailTable->execute();
        }

        echo "\nNeeds to anonymize: $sizeOfResultSelectUserTable";
        echo isset($resultUpdateUserTable) ? "\nAnonymized Users: $resultUpdateUserTable" : "\nAnonymized Users: 0";
        echo isset($resultUpdateMailTable) ? "\nAnonymized Emails: $resultUpdateMailTable" : "\nAnonymized Emails: 0";

        $logMessage = 'Anonymization: ';
        $logMessage .= isset($resultUpdateUserTable) ? "\nAnonymized Users: $resultUpdateUserTable" : "\nAnonymized Users: 0";
        $logMessage .= isset($resultUpdateMailTable) ? "\nAnonymized Emails: $resultUpdateMailTable" : "\nAnonymized Emails: 0";

        $timeEnd = microtime(true);
        $timePassed = round($timeEnd - $timeStart, 3);

        $substitution = [
            '{USERS}' => isset($resultUpdateUserTable) ? $resultUpdateUserTable : '',
            '{MAILS}' => isset($resultUpdateMailTable) ? $resultUpdateMailTable : '',
            '{DATE}' => date('Y-m-d'),
            '{TIME}' => $timePassed . 's.',
        ];

        $email = DocumentTemplate::findOne(['category' => 2, 'module_id' => 1]);
        $emailTemplate = str_replace(array_keys($substitution), array_values($substitution), $email->template);
        $emailTitle = str_replace(array_keys($substitution), array_values($substitution), $email->title);

        $message = Yii::$app->mailer->compose('layouts/outlook', [
                'content' => $emailTemplate,
                'title' => $emailTitle
            ])
            ->setFrom('')
            ->setTo(explode(";", Yii::$app->params['adminEmail']))
            ->setSubject($emailTitle)
            ->send();

        $logMessage .= "<strong>Time:</strong> " . $timePassed . 's.';
        $logEntry = new LogEntry();
        $logEntry->module_id = null;
        $logEntry->category = 'gdpr';
        $logEntry->message = $logMessage;
        $logEntry->save();

        return ExitCode::OK;
    }
}
