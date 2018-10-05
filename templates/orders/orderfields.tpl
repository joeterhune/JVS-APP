<script type="text/javascript">
    $('table.orderfields').ready(function() {
        $(".datepicker").datepicker({
            showOn: "both",
            buttonImageOnly: true,
            buttonText: "Select date",
            format: 'mm/dd/yyyy',
            buttonImage: "/style/images/calendar.gif",
            autoclose: true,
            todayHighlight: true,
            todayBtn: 'linked',
            changeMonth: true,
            changeYear: true,
            yearRange: "-5:+3"
        });
		
		$(".timepicker").datetimepicker({
			format: 'HH:ii p',
            autoclose: true,
            todayHighlight: true,
            showMeridian: true,
            startView: 1,
			pickDate: false
		});
    });
	$('.ui-datepicker-trigger').wrap('<div class="input-group-addon"></div>');
</script>

        {if ($docid != "") && ($ucn == "")}
        <p>
            Error: no ucn defined for this workflow document: ({$docid})
        </p>
        {/if}
        
        {$formfields}
        
        {$builtins}
        
        {$esigtpl}
        
        <script type="text/javascript">
            var chmailarr = [{$chmailarr}];
        </script>
