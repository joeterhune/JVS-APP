    var labels = "";
    var jsonfile_cat = JSON.parse(JSON.stringify({$inOutCategories}));
	jsonfile_cat.map(function(e) {
		if(e.category){
			labels = e.category.map(function(e2) {
				return e2.label;
			});
		}
	});
		
	var jsonfile_data = JSON.parse(JSON.stringify({$inOutDataSet}));
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
	
	/*var ctx = document.getElementById('inOutChartjsDiv-{$division}').getContext('2d');
	var color = Chart.helpers.color;
	var inOutChartjsDiv_{$division}_line = new Chart(ctx, {
		type: 'bar',
		data: {
			labels: labels,
			//data: data,
		    datasets: [
			    {
			    	label: [series[0]],
			        data: data[0],
			        fill: false,
			        backgroundColor: color(window.chartColors.blue).alpha(0.5).rgbString(),
					borderColor: color(window.chartColors.blue).alpha(0.5).rgbString(),
			    },
			    {
			    	label: [series[1]],
			        data: data[1],
			        fill: false,
			        backgroundColor: color(window.chartColors.green).alpha(0.5).rgbString(),
					borderColor: color(window.chartColors.green).alpha(0.5).rgbString(),
			    },
			    {
			    	label: [series[2]],
			        data: data[2],
			        fill: false,
			        backgroundColor: color(window.chartColors.red).alpha(0.5).rgbString(),
					borderColor: color(window.chartColors.red).alpha(0.5).rgbString(),
			    },
			    {
			    	label: [series[3]],
			        data: data[3],
			        fill: false,
			        backgroundColor: color(window.chartColors.purple).alpha(0.5).rgbString(),
					borderColor: color(window.chartColors.purple).alpha(0.5).rgbString(),
			    },
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
				text: 'In/Out'
			},
			scales: {
				yAxes: [
					{
						scaleLabel: {
		                    display: true,
		                    labelString: '# Cases'
		                }
					}
				],
				xAxes: [
					{
						scaleLabel: {
		                    display: false
		                }
					}
				],
			}
		}
	});*/
		
	var ctx = document.getElementById('inOutChartjsDiv-{$division}').getContext('2d');
	var color = Chart.helpers.color;
	var inOutChartjsDiv_{$division}_line = new Chart(ctx, {
		type: 'line',
		data: {
			labels: labels,
			//data: data,
		    datasets: [
			    {
			    	label: [series[0]],
			        data: data[0],
			        fill: true,
			        backgroundColor: color(window.chartColors.blue).alpha(0.1).rgbString(),
					borderColor: window.chartColors.blue,
			    },
			    {
			    	label: [series[1]],
			        data: data[1],
			        fill: true,
			        backgroundColor: color(window.chartColors.green).alpha(0.1).rgbString(),
					borderColor: window.chartColors.green,
			    },
			    {
			    	label: [series[2]],
			        data: data[2],
			        fill: true,
			        backgroundColor: color(window.chartColors.red).alpha(0.1).rgbString(),
					borderColor: window.chartColors.red,
			    },
			    {
			    	label: [series[3]],
			        data: data[3],
			        fill: true,
			        backgroundColor: color(window.chartColors.purple).alpha(0.1).rgbString(),
					borderColor: window.chartColors.purple,
			    },
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
				text: 'In/Out'
			},
			scales: {
				yAxes: [
					{
						scaleLabel: {
		                    display: true,
		                    labelString: '# Cases'
		                }
					}
				],
				xAxes: [
					{
						scaleLabel: {
		                    display: false
		                }
					}
				],
			}
		}
	});
	
	/*var ctx = document.getElementById('inOutChartjsDiv-{$division}').getContext('2d');
	var color = Chart.helpers.color;
	var inOutChartjsDiv_{$division}_bar = new Chart(ctx, {
		type: 'bar',
		data: {
			labels: labels,
			//data: data,
		    datasets: [
			    {
			    	label: [series[0]],
			        data: data[0],
			        fill: false,
			        backgroundColor: color(window.chartColors.blue).alpha(0.5).rgbString(),
					borderColor: color(window.chartColors.blue).alpha(0.5).rgbString(),
					stack: 'Stack 0',
			    },
			    {
			    	label: [series[1]],
			        data: data[1],
			        fill: false,
			        backgroundColor: color(window.chartColors.green).alpha(0.5).rgbString(),
					borderColor: color(window.chartColors.green).alpha(0.5).rgbString(),
					stack: 'Stack 0',
			    },
			    {
			    	label: [series[2]],
			        data: data[2],
			        fill: false,
			        backgroundColor: color(window.chartColors.red).alpha(0.5).rgbString(),
					borderColor: color(window.chartColors.red).alpha(0.5).rgbString(),
					stack: 'Stack 1',
			    },
			    {
			    	label: [series[3]],
			        data: data[3],
			        fill: false,
			        backgroundColor: color(window.chartColors.purple).alpha(0.5).rgbString(),
					borderColor: color(window.chartColors.purple).alpha(0.5).rgbString(),
					stack: 'Stack 1',
			    },
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
				text: 'In/Out'
			},
			scales: {
				yAxes: [
					{
						scaleLabel: {
		                    display: true,
		                    labelString: '# Cases',
		                    stacked: true,
		                    fontStyle: "bold",
		                }
					}
				],
				xAxes: [
					{
						scaleLabel: {
		                    display: false,
		                    stacked: true,
		                }
					}
				],
			}
		}
	});*/