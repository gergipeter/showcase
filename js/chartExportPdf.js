generatePDF: function () {
    var deferreds = [];
    var doc = new jsPDF("l", "pt", "a4");
    var perspectiveName = $.trim($('#myNavbar li.active a').text());

    for (let i = 1; i <= 2; i++) {
        var deferred = $.Deferred();
        deferreds.push(deferred.promise());
        this.generateCanvas(i, doc, deferred, perspectiveName);
    }

    $.when.apply($, deferreds).then(function () {
        var canvas = document.createElement('canvas');
        var context = canvas.getContext('2d');
        context.clearRect(0, 0, canvas.width, canvas.height);

        var titles = [];
        var imgData = [];
        var svgArray = [];
        var dimensions = [];
        var xAxisMargin = 15;

        $(".highcharts-container").find().prevObject.each(function (i, element) {
            var id = element.id;

            if (typeof ($('#' + id).parent().attr('data-chart-id')) !== 'undefined') {
                var chartIDs = $('#' + id).parent().attr('data-chart-id');
                var widthClass = this.getChartWidthClass(chartIDs);

                dimensions.push(widthClass);

                var svgString = $('#' + id + ' svg').prop('outerHTML').replace(/>\s+/g, '>').replace(/\s+</g, '<').replace(/<canvas.+/g, '');
                svgArray.push(svgString);

                canvg(canvas, svgString);
                imgData.push(canvas.toDataURL('image/jpeg', 1));

                titles.push($('.chart-container-' + chartIDs).find('.panel-heading').attr('title'));
            }
        });

        imgData.forEach(function (value, i) {
            doc.text(30, 40, titles[i]);
            this.addImageByDimension(doc, imgData[i], dimensions[i], xAxisMargin);

            if (i !== svgArray.length - 1) {
                doc.addPage();
            }
        });

        $('#loader-wrapper').addClass('full-opacity', 400);
        doc.save(perspectiveName + '.pdf');
    }.bind(this));
},

generateCanvas: function (i, doc, deferred, perspectiveName) {
    $('html, body').scrollTop(0);

    if (i === 1) {
        html2canvas($("#siemens_logo")).then(function (canvas) {
            var imgData2 = canvas.toDataURL("image/png");
            doc.addImage(imgData2, 'PNG', 30, 40, 0, 0);
            deferred.resolve();
        });
    }

    if (i === 2) {
        html2canvas($("#dashFilterBlock")).then(function (canvas) {
            var imgData = canvas.toDataURL("image/png");
            doc.setFontSize(20);
            doc.text(230, 80, perspectiveName);
            doc.setFontSize(20);
            doc.addImage(imgData, 'PNG', 100, 100, 0, 0);
            doc.addPage();
            deferred.resolve();
        });
    }
},

getChartWidthClass: function (chartIDs) {
    var widthClass = $('.chartBlock[data-chart-id=' + chartIDs + ']').attr('class');

    if (widthClass.indexOf("special-20") >= 0) {
        return '20';
    } else if (widthClass.indexOf("col-md-4") >= 0) {
        return '33';
    } else if (widthClass.indexOf("col-md-6") >= 0) {
        return '50';
    } else if (widthClass.indexOf("col-md-8") >= 0) {
        return '66';
    } else if (widthClass.indexOf("col-md-12") >= 0) {
        return '100';
    }

    return '66'; // Default
},

addImageByDimension: function (doc, imgData, dimension, xAxisMargin) {
    switch (dimension) {
        case '20':
            doc.addImage(imgData, 'JPG', xAxisMargin, 80, 300, 400);
            break;
        case '33':
            doc.addImage(imgData, 'JPG', xAxisMargin, 80, 500, 400);
            break;
        case '50':
            doc.addImage(imgData, 'JPG', xAxisMargin, 80, 780, 370);
            break;
        case '66':
            doc.addImage(imgData, 'JPG', xAxisMargin, 80, 800, 333);
            break;
        case '100':
            doc.addImage(imgData, 'JPG', xAxisMargin, 80, 800, 222);
            break;
        default:
            doc.addImage(imgData, 'JPG', xAxisMargin, 80, 800, 333);
            break;
    }
}
