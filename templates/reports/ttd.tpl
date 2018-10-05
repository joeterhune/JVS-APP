    var labels = "";
    var jsonfile_cat = JSON.parse(JSON.stringify({$ttdCategories}));
	jsonfile_cat.map(function(e) {
		labels = e.category.map(function(e2) {
			return e2.label;
		});
	});
		
	var jsonfile_data = JSON.parse(JSON.stringify({$ttdDataSet}));
	var count = 0;
	var data = [];
	jsonfile_data.map(function(e) {
		data[count] = e.data.map(function(e2) {
			return e2.value;
		});
		count++;
	});
	
	var series = jsonfile_data.map(function(e) {
	   return e.seriesname;
	});
		
	var ctx = document.getElementById('ttdChartjsDiv-{$division}').getContext('2d');
	var color = Chart.helpers.color;
	var ttdChartjsDiv_{$division}_line = new Chart(ctx, {
		type: 'line',
		data: {
			labels: labels,
			//data: data,
		    datasets: [
			    {
			    	label: [series[0]],
			        data: data[0],
			        fill: false,
			        backgroundColor: color(window.chartColors.blue).alpha(0.5).rgbString(),
					borderColor: color(window.chartColors.blue).rgbString(),
			    },
			    {
			    	label: [series[1]],
			        data: data[1],
			        fill: false,
			        backgroundColor: color(window.chartColors.green).alpha(0.5).rgbString(),
					borderColor: color(window.chartColors.green).rgbString(),
			    },
			    {
			    	label: [series[2]],
			        data: data[2],
			        fill: false,
			        backgroundColor: color(window.chartColors.red).alpha(0.5).rgbString(),
					borderColor: color(window.chartColors.red).rgbString(),
			    }
		    ]
		},
		options: {
			// Elements options apply to all of the options unless overridden in a dataset
			// In this case, we are setting the border of each horizontal bar to be 2px wide
				elements: {
					rectangle: {
					borderWidth: 2,
				}
			},
			responsive: true,
			maintainAspectRatio: false,
			legend: {
				display: true,
				position: 'bottom',
			},
			title: {
				display: true,
				text: 'Time to Disposition'
			},
			scales: {
				yAxes: [
					{
						scaleLabel: {
		                    display: true,
		                    labelString: '% of Cases Disposed',
		                    fontStyle: "bold",
		                }
					}
				],
				xAxes: [
					{
						scaleLabel: {
		                    display: true,
		                    labelString: 'Case Filing Date',
		                    fontStyle: "bold",
		                }
					}
				],
			}
		}
	});