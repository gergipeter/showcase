var FileUploadHelper = {
    fileuploadprogressall: function (e, data) {
        var progress = parseInt(data.loaded / data.total * 100, 10);
        if (progress > 0) {
            $('.upload-panel #progress').show();
            $('.upload-panel .fileinput-button').hide();
        }
        $('.upload-panel #progress .progress-bar').css('width', progress + '%');
    },

    fileuploaddone: function (e, data, record_id, category) {
        $('.upload-panel #progress').hide().find('.progress-bar').css('width', 0);
        $('.upload-panel .fileinput-button').show();

        if (data.result && data.result.error === undefined) {
            $('.upload-panel .table-files .no-files-tr').remove();
            var linkText = data.result.name;
            var linkLength = 25;

            if (linkText.length > linkLength) {
                linkText = linkText.slice(0, linkLength) + '...';
            }

            var linkObj = $('<a>').attr({
                'href': data.result.url,
                'data-toggle': 'tooltip',
                'title': data.result.name,
                'data-placement': 'right'
            }).text(linkText);

            var trObj = $('<tr>')
                .append($('<td>').append(linkObj))
                .append($('<td>').append(data.result.size))
                .append($('<td>').append($('<a>').attr({
                    'href': '#',
                    'class': 'delete-attachment-single',
                    'data-file_name': data.result.name
                }).html('<span class="glyphicon glyphicon-trash" aria-hidden="true"></span>')));

            var listCustomAttachments = $('#list_custom_attachments');

            listCustomAttachments.append(trObj);

            $(".delete-attachment-single").off("click").on("click", function() {
                event.preventDefault();
                var trIndex = $(this).closest('tr')[0].rowIndex;
                $.ajax({
                    url: '../request/delete-custom-attachment',
                    type: 'POST',
                    data: {
                        record_id: record_id,
                        category: category,
                        file_name: $(this).attr("data-file_name"),
                    },
                }).done(function() {
                    listCustomAttachments[0].deleteRow(trIndex);
                });
            });

            $('#errormessage').html('<span style="color:green;font-weight: bold;">File(s) uploaded!</span>');
            $('#custom_attachment_field').css('margin-bottom', '0');
        } else {
            if (data.result.error !== undefined) {
                $('#errormessage').html('<span style="color:red;font-weight: bold;">File(s) upload error!</span>');
            }
        }
    },

    fileuploadfail: function (e, data) {
        console.log(data);
        $('.upload-panel #progress').hide().find('.progress-bar').css('width', 0);
        $('.upload-panel .fileinput-button').show();
        $('#errormessage').html('<span style="color:red;font-weight: bold;">File(s) upload error!</span>');
    },
};
