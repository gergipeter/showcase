<?php

namespace console\controllers;

use yii\base\ErrorException;
use yii\console\Controller;
use yii\console\ExitCode;
use common\models\User;
use Yii;

class LdapController extends Controller {

    const MAILSERVER_TIMEOUT = false;

    private $ldapHost = "";
    private $ldapPort = 636;
    private $usr = "";
    private $pwd = "";

    public function init() {
        parent::init();
        \Yii::$app->user->setIdentity(User::findOne(['id' => 3652])); // Robot Consolidator
    }

    public function actionScd()
    {
        $ldapUri = "ldaps://{$this->ldapHost}:{$this->ldapPort}";

        ldap_set_option(null, LDAP_OPT_PROTOCOL_VERSION, 3);
        ldap_set_option(null, LDAP_OPT_DEBUG_LEVEL, 7);
        ldap_set_option(null, LDAP_OPT_X_TLS_REQUIRE_CERT, 0);

        if (!($connect = ldap_connect($ldapUri))){
           $this->outputError("Could not connect to LDAP server");
           return ExitCode::UNSPECIFIED_ERROR;
        }
        $this->outputInfo("Connected to {$this->ldapHost}");

        ldap_set_option($connect, LDAP_OPT_PROTOCOL_VERSION, 3);
        ldap_set_option($connect, LDAP_OPT_DEBUG_LEVEL, 7);
        ldap_set_option($connect, LDAP_OPT_X_TLS_REQUIRE_CERT, 0);

        try {
            $bind = ldap_bind($connect, $this->usr, $this->pwd);
        } catch (ErrorException $e) {
            $this->outputError($e->getMessage());
            $this->outputError(ldap_error($connect));
            return ExitCode::UNSPECIFIED_ERROR;
        }

        $filter = '';

        $ldapSearch = ldap_search($connect, '', $filter);
        $info = ldap_get_entries($connect, $ldapSearch);

        echo print_r($info, true);
        ldap_unbind($connect);

        return ExitCode::OK;
    }

    private function outputInfo($message) {
        echo "INFO: $message" . PHP_EOL;
    }

    private function outputError($message) {
        echo "ERROR: $message" . PHP_EOL;
    }
}
