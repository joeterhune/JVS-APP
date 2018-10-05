	var jsonfile = JSON.parse(JSON.stringify({$json}));
	var labels = jsonfile.map(function(e) {
		e.label = e.label.replace("<br/>", " ");
	   return e.label;
	});
		
	var data = jsonfile.map(function(e) {
	   return e.value;
	});

	var ctx = document.getElementById('{$graphType}ChartjsDiv-{$division}').getContext('2d');
	var color = Chart.helpers.color;
	var {$graphType}ChartjsDiv_{$division}_horizontalBar = new Chart(ctx, {
		type: 'horizontalBar',
		width: '100%',
		height: '100%',
		data: {
			//labels: labels,
			//data: data,
			//backgroundColor: [color(window.chartColors.green).alpha(0.5).rgbString(), color(window.chartColors.yellow).alpha(0.5).rgbString(), color(window.chartColors.red).alpha(0.5).rgbString()], 
		    datasets: [
			    {
			    	label: [labels[0]],
			        data: [data[0]],
			        backgroundColor: color(window.chartColors.green).alpha(0.5).rgbString(),
			        borderColor: window.chartColors.green,
			        borderWidth: 1,
			    },
			    {
			    	label: [labels[1]],
			        data: [data[1]],
			        backgroundColor: color(window.chartColors.yellow).alpha(0.5).rgbString(),
			        borderColor: window.chartColors.yellow,
			        borderWidth: 1,
			    },
			    {
			    	label: [labels[2]],
			        data: [data[2]],
			        backgroundColor: color(window.chartColors.red).alpha(0.5).rgbString(),
			        borderColor: window.chartColors.red,
			        borderWidth: 1,
			    },
			    {if $graphType == "pend_crit"}
			    	{
				    	label: [labels[3]],
				        data: [data[3]],
				        backgroundColor: color(window.chartColors.purple).alpha(0.5).rgbString(),
				        borderColor: window.chartColors.purple,
				        borderWidth: 1,
			    	},
			    {/if}
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
				position: 'top',
			},
			title: {
				display: true,
				text: '{$caption} - {$month}'
			},
			scales: {
				yAxes: [
					{
						scaleLabel: {
		                    display: true,
		                    labelString: '{$xAxisName}',
		                    fontStyle: "bold",
		                }
					}
				],
				xAxes: [
					{
						scaleLabel: {
		                    display: true,
		                    labelString: '{$yAxisName}',
		                    fontStyle: "bold",
		                }
					}
				],
			},
			animation: {
	            //duration: 1000,
	            //easing: "easeInCirc"
	        }
		}
	});
	
	document.getElementById('{$graphType}ChartjsDiv-{$division}').onclick = function (evt) {
		var activePoints = {$graphType}ChartjsDiv_{$division}_horizontalBar.getElementsAtEventForMode(evt, 'point', {$graphType}ChartjsDiv_{$division}_horizontalBar.options);
	    var firstPoint = activePoints[0];
	    var label = {$graphType}ChartjsDiv_{$division}_horizontalBar.data.datasets[firstPoint._datasetIndex].label[firstPoint._index];
	    var value = {$graphType}ChartjsDiv_{$division}_horizontalBar.data.datasets[firstPoint._datasetIndex].data[firstPoint._index];
	        
	    label = label.replace(/\s/g, "");
	    label = label.replace("+", "");
	    
	    {if $graphType == 'pend_juryTrials' || ($graphType == 'pend_contested') || ($graphType == 'pend_uncontested')}
	    	label = "{$graphType}";
	    {else if $graphType == 'pend_crit'}
	    	if(label == "NoActivity180Days"){
	    		label = "pend_noAct180";
	    	}
	    	else if(label == "NoActivity300Days"){
	    		label = "pend_noAct300";
	    	}
	    	else if(label == "MotionwithNoHearing"){
	    		label = "pend_motNoEvent";
	    	}
	    	else{
	    		label = "pend_los";
	    	}
	    {else}
	    	label = "{$graphType}_" + label;
	    {/if}
	    
		showDivRpt('{$division}', '{$function_month}', '{$courtType}', label);
	};