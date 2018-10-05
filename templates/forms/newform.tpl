<!DOCTYPE html>
    <html>
        <head>
            <title>Form Designer - Create Form</title>
        </head>
    
        <body>
            <h3>Create Form</h3>
            <form method="post" action="newform-post.php" enctype="multipart/form-data">
                <table>
                    <tr>
                        <td style="vertical-align: top">
                            Form Name
                        </td>
                        <td>
                            <input type="text" name="form_name" size="100"/>
                        </td>
                    </tr>
                    <tr>
                        <td>
                            Copy Form From
                        </td>
                        <td>
                            <select name="copy_from">
                                <option value="0">NOTHING - BLANK</option>
                                {foreach $forms as $form}<option value="{$form.form_id}">{$form.form_name}</option>
                                {/foreach}
                            </select>
                        </td>
                    </tr>
                    
                    <tr>
                        <td>OR</td>
                    </tr>
                    
                    <tr>
                        <td>
                            Import RTF Form
                        </td>
                        <td>
                            <input id="rtfUpload" class="ulfile" type="file" name="rtfUpload"/>
                        </td>
                    </tr>
                    
                </table>
                
                <button class="btnSubmit" tytpe="button">Submit</button>
                <!--<input type="submit" value="Save"/>-->
                <input type="button" value="Cancel" onClick="window.location='index.php';">
            </form>
        </body>
    </html>