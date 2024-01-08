<?php

namespace console\controllers;

use yii\console\Controller;
use common\models\User;
use common\helpers\ExcelExporter;
use Yii;
use frontend\modules\indigo\helpers\PeriodHelper;

class ExportExcelController extends Controller {

    public static $MAILSERVER_TIMEOUT = false;

    public function init() {
        parent::init();
        Yii::$app->user->setIdentity(User::findOne(['id' => 3652])); // Robot Consolidator
    }

    /**
     * Used for Export to EXCEL for SupplyOn.
     * Creates two Excel files from dash2.data_supplyon_dash table and stores them in console/runtime folder.
     */
    public function actionExportExcelSupplyon(){

        $timeStart = microtime(true);
        ini_set('memory_limit','8192M');
        
        $connection = Yii::$app->db;      
        $year = PeriodHelper::getDefaultFiscalYear();
        
        $dataAll  = $connection->createCommand("")->queryAll();
        $dataCurrentFY = $connection->createCommand("")->queryAll();
        
        $filenameAll = Yii::getAlias('@console/runtime/supplyon_export.xlsx');
        $filenameCurrentFY = Yii::getAlias('@console/runtime/supplyon_export_' . $year . '.xlsx');
        
        ExcelExporter::render($dataAll, $filenameAll);
        ExcelExporter::render($dataCurrentFY, $filenameCurrentFY);
        
        $timeEnd = microtime(true);
        $timePassed = round($timeEnd - $timeStart, 3);

        $this->printMemoryUsage();

        echo "Time: $timePassed s" . PHP_EOL;
        return ExitCode::OK;
    }

    /**
     * Print memory usage information.
     */
    private function printMemoryUsage() {
        echo "Memory: " . memory_get_usage() / 1024 / 1024 . " MB" . PHP_EOL;
        echo "Memory REAL: " . memory_get_usage(true) / 1024 / 1024 . " MB" . PHP_EOL;
        echo "Peak memory: " . memory_get_peak_usage() / 1024 / 1024 . " MB" . PHP_EOL;
        echo "Peak memory REAL: " . memory_get_peak_usage(true) / 1024 / 1024 . " MB" . PHP_EOL;
    }
}
