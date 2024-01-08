<?php

namespace common\helpers;

use Yii;
use Box\Spout\Writer\WriterFactory;
use Box\Spout\Common\Type;
use Box\Spout\Writer\Style\StyleBuilder;
use Box\Spout\Writer\Style\Color;

class ExcelExporter {
    
    /**
     * Renders data to a file.
     *
     * @param array $data
     * @param string $filename
     * @return void
     */
    public static function render($data, $filename) {
        self::initializeSpout();
        $writer = WriterFactory::create(Type::XLSX);
        self::configureWriter($writer, $filename);
        $writer->addRowWithStyle(array_keys($data[0]), self::createHeaderStyle());
        $writer->addRows($data);
        $writer->close();
    }
    
    /**
     * Renders data to the browser.
     *
     * @param array $data
     * @param string $filename
     * @param bool $writeKeysAsHeader
     * @return void
     */
    public static function renderBrowser($data, $filename, $writeKeysAsHeader = false) {
        self::initializeSpout();
        $writer = WriterFactory::create(Type::XLSX);
        self::configureWriter($writer, $filename);
        if ($writeKeysAsHeader) {
            $writer->addRow(array_keys($data[0]));
        }
        $writer->addRows($data);
        $writer->close();
    }

    /**
     * Initializes Spout by requiring its autoload file.
     *
     * @return void
     */
    private static function initializeSpout() {
        require_once Yii::getAlias('@console/components/') . 'Spout/Autoloader/autoload.php';
    }

    /**
     * Configures the writer with common settings.
     *
     * @param \Box\Spout\Writer\WriterInterface $writer
     * @param string $filename
     * @return void
     */
    private static function configureWriter($writer, $filename) {
        $writer->setTempFolder(Yii::getAlias('@console') . '/runtime');
        $writer->openToFile($filename);
        $writer->setDefaultRowStyle(self::createDefaultStyle());
    }

    /**
     * Creates and returns the default row style.
     *
     * @return \Box\Spout\Writer\Style\Style
     */
    private static function createDefaultStyle() {
        return (new StyleBuilder())->setShouldWrapText(false)->build();
    }

    /**
     * Creates and returns the header row style.
     *
     * @return \Box\Spout\Writer\Style\Style
     */
    private static function createHeaderStyle() {
        return (new StyleBuilder())
            ->setShouldWrapText(false)
            ->setBackgroundColor(Color::LIGHT_BLUE)
            ->setFontBold()
            ->build();
    }
}
