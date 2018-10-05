            <script src="/javascript/ckeditor/ckeditor.js"></script>
	        <script type="text/javascript">
	                // do this before the first CKEDITOR.replace( ... )
	                CKEDITOR.timestamp = +new Date;
	        </script>
	        <script src="/javascript/ckeditor/adapters/jquery.js"></script>
            <script type="text/javascript">
                $(document).ready(function (){
                	{literal}
                		$.blockUI({message: '<h1><img src="/images/busy.gif"/> Please Wait </h1>', fadeIn: 0});
                	{/literal}
                    var pane = $('#orderDiv-{$ucn}').closest('.orderDiv');
                        
                    var queue='{$data.queue}';
                    var docid='{$docid}';
                    var ucn = '{$ucn}';
                    orderDiv = $('#orderDiv-{$ucn}');
                    
                    var pdfht=$(orderDiv).height()-30;
                    // acrobat and IE like to cache this, so...
                    var t=new Date().getTime();
                    var formname = EncodeURI('{$data.formname}');
                
                    {literal}
                    	var postData = {ucn: ucn, formname: formname, t: t, json: 1};
                    {/literal}
                
                    {if $docid}
                    	postData.docid = {$docid};
                    {/if}
                
                    $.ajax({
                        url: '/orders/pickorder.php',
                        data: postData,
                        async: true,
                        success: function(data) {
                            var json = $.parseJSON(data);
                            $(orderDiv).find('.htmlformdiv').first().html(json.html);
                            // Enable the "Parties" and "Preview" buttons if an order type has been selected
                            var selType = $(orderDiv).find('.formid').val();
                            if (selType != "") {
                                $(orderDiv).find('.previewbutton,.partiesbutton').attr('disabled',false);
                            }
                        }
                    });
                    
                    $.ajax({
                        url: '/orders/preview.php',
                        data: postData,
                        async: true,
                        success: function(data) {
                            $(orderDiv).find('.previewdiv').first().html(data.html);
                        }
                    });
                    
                    postData.isOrder = $(pane).find('.isOrder').val();
                    
                    $.ajax({
                        url: '/workflow/parties.php',
                        data: postData,
                        async: true,
                        success: function(data) {
                            $(orderDiv).find('.xmlpartiesdiv').first().html(data.html);
                            {if !$docid}
                            	$.unblockUI();
                            {/if}
                        }
                    });
                    
                    {if $docid}
	                    $(document).one("ajaxStop", function() {
							//$(pane).find('.previewbutton').trigger('click');
							$(pane).find('.previewbutton').first().trigger('click');
							$.unblockUI();
						});
					{/if}
                    
                    var cvRow = $(pane).find('.xmlviewctrl');
                    var pos = $(cvRow).offset();
                    // The top of the editor should be 2* (the height of the button row + 5) offset from the top of the button row
                    var editTop = pos.top + (2 * ($(cvRow).height() + 5));
                    var winHt = $(window).height();
                    PDFIFRAMEHEIGHT = winHt - editTop;
                    MAILIFRAMEHEIGHT = PDFIFRAMEHEIGHT-35;
                    
                    var ht=$(window).height()-100;
                    $(orderDiv).find(".xmlpdfdiv").first().html('<iframe class="pdfiframe" style="width:100%;height:' +PDFIFRAMEHEIGHT+'px"></iframe>');
                    //$(orderDiv).find(".xmlpdfdiv").first().html('<br><iframe class="pdfiframe" style="width:100%;height:100%"></iframe>');
                    $(orderDiv).find(".xmlmailpdfdiv").first().html('<iframe class="mailpdfiframe" style="width:100%;height:'+MAILIFRAMEHEIGHT+'px"></iframe>');
                
                    if ($(pane).find('.didgen').val() != 0) {
                        pvb = $(orderDiv).find('.previewbutton').first();
                        $(pvb).removeAttr('disabled');
                    }
                    
                    {if $isSigned == 1}
	                	$(orderDiv).find('.orderviewbutton').removeAttr('disabled');
	                {/if}
                    
                    function OrderShowMailDisabledDialog() {
                       $("#maildisableddialog").dialog();
                    }
                });
            </script>
            
            <div id="orderDiv-{$ucn}" class="orderDiv" style="width:98%">
				<div class="row" style="padding-left:1.25%;">
	                <div class="xmlviewctrl" class="btn-group" role="group">
	                    <button type="button" class="btn btn-primary btn-sm xmlbutton" data-type="htmlform"><i class="fa fa-file-o"></i> Form</button>
	                    
	                    <button type="button" class="btn btn-primary btn-sm xmlbutton partiesbutton" data-type="xmlparties"><i class="fa fa-users"></i> Parties</button>
	                    <button type="button" class="btn btn-primary btn-sm xmlbutton previewbutton" data-type="preview"><i class="fa fa-eye"></i> Preview</button>
	                    
	                    {if $cansign > 0}
	                    <button type="button" class="btn btn-primary btn-sm signbutton xmlsignbutton" data-type="xmlsignbutton" disabled="disabled"><i class="fa fa-pencil"></i> Sign</button>
	                    
	                    <select class="signAs" name="signAs" style="display: none">
	                        <option value="" selected="selected">Please select a signature to apply</option>
	                        {foreach $esigs as $signame}
	                            {$sel = ""};
	                            {if (($cansign == 1) || ($signame.user_id == $user))}
	                                {$sel = "selected=\"selected\""}
	                            {/if}
	                            <option value="{$signame.user_id}" {$sel}>{$signame.fullname}</option>
	                        {/foreach}
	                    </select>
	                    {/if}
	                    
	                    <span class="esigstatus statusind"></span>
	                    
	                    <button type="button" class="btn btn-primary btn-sm xmlbutton orderviewbutton" data-type="xmlpdf" disabled="disabled"><i class="fa fa-eye"></i> Create PDF</button>
	                    
	                    <button type="button" class="btn btn-primary btn-sm xmlbutton xmlmailbutton revisedisable" data-type="xmlmail" disabled="disabled"><i class="fa fa-envelope"></i> Mail</button>
	                    
	                    <span class="mailstatus statusind" style="color: green"></span>
	                    
	                    <button type="button" class="btn btn-primary btn-sm xmlbutton xmlefilebutton revisedisable" data-type="xmlefile" disabled="disabled"><i class="fa fa-file"></i> E-File</button>
	                    
	                    <span class="emailstatus statusind" style="color: green"></span>
	                    <span class="efilestatus statusind" style="color: green"></span>
	                    
	                    <button type="button" class="btn btn-primary btn-sm xmlbutton transferbutton" data-type="xmltransfer" disabled="disabled"><i class="fa fa-exchange"></i> Transfer</button>
	                    
	                    <button type="button" class="btn btn-success btn-sm xmlbutton finishbutton" data-type="xmlfinishbutton" disabled="disabled"><i class="fa fa-check"></i> Finish</button>
	                    
	                    <span class="xmlstatus statusind" style="font-size:10pt"></span>
	                </div>
	                
	                <div style="float: right">
	                    <a class="helpLink" data-context="orders">
	                        <img class="toolbarBtn" style="height: 20px !important; width: 20px;" alt="Help" title="Help" src="/images/help_icon.png">
	                    </a>
	                </div>
               </div>
			   <div class="row">
                <div class="orderDivs col-md-12">
                    <div class="htmlformdiv buttondiv" style="height: 96%;">
                        
                    </div>
                    <div class="previewdiv buttondiv" style="display:none;">
                        
                    </div>
                    <div class="xmlpdfdiv buttondiv" style="display:none;">
                        
                    </div>
                    <div class="xmlpartiesdiv buttondiv" style="display:none;">
                        
                    </div>
                    <div class="xmlmaildiv buttondiv" style="display:none;">
                        <div>
                            <button type="button" class=" btn btn-primary btn-sm mailConfirm xmlmailconfirmbutton">
                                Confirm Mailing
                            </button>
                        </div><!--
                            <div class="xmlmailspan">
                                
                            </div>
                        -->
                        <div class="xmlmailpdfdiv">
                            
                        </div>
                    </div>
                    
                    <div class="xmlefilediv buttondiv" style="display:none">
                        <button type="button" class="emailConfirm xmlemailconfirmbutton">Email Parties with Email Addresses</button>
                        <button type="button" class="efileConfirm xmlefileconfirmbutton">Submit Document for e-Filing</button>
                        <!--" onClick="OrderEfileConfirm();"/>-->
                        <div class="xmlefilespan">
                            <p>
                                Click on the <b>E-File Document</b> button to electronically file the document with
                                the Clerk of Court, and e-mail parties with supplied e-mail addresses.
                            </p>
                        </div>
                       
                    </div>
                    
                    <div class="xmltransferdiv buttondiv" style="display:none">
                        Work Queue:
                        <select class="xmltransferqueue">
                            <option value="">Select Queue</option>
                            {foreach $real_xferqueues as $user}<option value="{$user.queue}">{$user.queuedscr}</option>{/foreach}
                        </select>
                        <button class="doTransfer">Transfer</button>
                    </div>
                    <input type="hidden" class="signeddoc"/>
                </div>
                
                <div class="hiddenvars" style="display: none">
                    <input type="hidden" class="ucn" value="{$ucn}"/>
                    <input type="hidden" class="didgen" value="{$didgen}"/>
                    <input type="hidden" class="docid" value="{$docid}"/>
                    <input type="hidden" class="isSigned" value="{$isSigned}"/>
                    <input type="hidden" class="pdf" value="{$pdf}"/>
                    <input type="hidden" class="fromAddr" value="{$fromAddr}"/>
                    <input type="hidden" class="fromwf" value="{$fromwf}"/>
                    <input type="hidden" class="isOrder" value="{$isOrder}"/>s
                    {if isset($filingId)}<input type="hidden" class="filingId" value="{$filingId}"/>{/if}
                </div>
                
                <div class="signaturediv" style="display: none">{$sigdiv}</div>
                </div>
            </div>
        </body>
    </html>