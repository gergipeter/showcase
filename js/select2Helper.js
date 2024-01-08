var Select2Helper = {
	_id: '#record-reasontext_id',
	catchResponseChangeSelected: function(data) {
		if (data && data.results && data.selected === '' && data.results.length === 1 && data.results[0].id) {
			data.selected = data.results[0].id;
		}
		return data;
	},
	_updateFilterSelect: function(id, data) {
		var selectElement = $('#' + id);
		selectElement.empty();
		$.each(data.results, function(index, result) {
			selectElement.append(new Option(result.text, result.id));
		});
	},
	processResults: function(data, params) {
		data = Select2Helper.catchResponseChangeSelected(data);
		Select2Helper._updateFilterSelect('ticket_supplier_searchbar', data);
		return data;
	},

	formatUserName: function(id, withEmail) {
		if (id === '') {
			return 'Select Agent...';
		}
		var userName;
		for (var i in Select2Helper.fullUserList) {
			if (id === Select2Helper.fullUserList[i].id) {
				var user = Select2Helper.fullUserList[i];
				userName = $('<span>');
				var email = $('<small>').addClass('text-muted').text(user.email);
				
				if (user.full_name && user.full_name !== null) {
					userName.text(user.full_name);
					if (withEmail) {
						userName.append('<br>', email);
					}
				} else {
					userName.append(email);
				}
				break;
			}
		}
		return userName;
	},
};
