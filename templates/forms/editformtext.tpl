<!DOCTYPE html>
    <html>
        <head>
            <title>Edit Form</title>
            <script src="https://e-services.co.palm-beach.fl.us/cdn/jslib/jquery-1.11.0.min.js"></script>
            <script src="//cdn.ckeditor.com/4.4.7/full/ckeditor.js"></script>
            <script src="//cdn.ckeditor.com/4.4.7/full/adapters/jquery.js"></script>
            <style>
                html, body {
                    height: 100%;
                }
            </style>
        </head>
        <body style="height:95%;width:100%">
            
            <script type="text/javascript">
            function LoadNewForm() {
                var formid=$("#formselect option:selected").val();
                if (formid!="") {
                    $.post("formtext.php?form_id="+formid,function(data) {
                        CKEDITOR.instances['editwindow'].setData(data);
                        $("#form_id").val(formid);
                    });
                } else {
                    data='';
                    CKEDITOR.instances['editwindow'].setData(data);
                    $("#form_id").val(formid);
                }
            }
            
            $(document).ready(function () {
                $("#formselect").change(LoadNewForm);
                CKEDITOR.replace('editwindow', {
                    customConfig: '/javascript/ckeditor/ckeditor_custom_config.js'
                });
            });
            </script>
            
            
           
            <div style="height: 100%">
                <form method=post action="editformtext-post.php" style="height: 100%">
                    <div>    
                        Form to Edit:
                        <select id="formselect" name="formid">
                            <option value="">Select a form</option>
                            {foreach $forms as $form}<option value="{$form.form_id}">{$form.form_name}</option>{/foreach}
                        </select>
                        
                        <input type="submit" value="Save"/>
                        <input type="button" value="Cancel" onclick="window.location='index.php';">
                    </div>
                    
                    <div style="height: 80%">
                        <textarea id="editwindow" name="editwindow"  style="height:100%;width:100%"></textarea>
                        <input type="hidden" name="form_id" id="form_id"/>
                    </div>    
                </form>
            </div>
        </body>
    </html>
    
    
