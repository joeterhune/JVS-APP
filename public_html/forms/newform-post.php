<?php
require_once ('../php-lib/db_functions.php');
require_once ('../php-lib/common.php');
require_once('Smarty/Smarty.class.php');

$smarty = new Smarty;
$smarty->setTemplateDir($templateDir);
$smarty->setCompileDir($compileDir);
$smarty->setCacheDir($cacheDir);

$dbh = dbConnect("icms");

$formname = getReqVal('form_name');
$copyfrom = getReqval('copy_from');
$rtfUpload = getReqVal('rtfUpload');


if ($copyfrom) {
    $query = "
        select
            form_body,
            form_fields,
            all_fields,
            efiling_document_description as docdesc
        from
            forms
        where
            form_id = :formid
    ";
    
    $copy = getDataOne($query, $dbh, array('formid' => $copyfrom));
    
    $query = "
        insert into
            forms (
                form_name,
                form_body,
                form_fields,
                all_fields,
                efiling_document_description
            ) values (
                :form_name,
                :form_body,
                :form_fields,
                :all_fields,
                :docdesc
            )
    ";
    doQuery($query, $dbh, array('form_name' => $formname, 'form_body' => $copy['formbody'], 'form_fields' => $copy['form_fields'],
                                'all_fields' => $copy['all_fields'], 'docdesc' => $copy['docdesc']));
} else if (sizeof($_FILES)) {
    $validTypes = array (
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'application/msword',
        'text/rtf'
    );
    
    $target_dir = "uploads/";
    $target_file = $target_dir . basename($_FILES["rtfUpload"]["name"]);
    $html_dir = "htmlout/";
    $uploadOk = 1;
    $imageFileType = pathinfo($target_file,PATHINFO_EXTENSION);
    
    $finfo = finfo_open(FILEINFO_MIME_TYPE);
    $mimetype = finfo_file($finfo, $_FILES["rtfUpload"]["tmp_name"]);
    
    if (!in_array($mimetype, $validTypes)) {
        echo "Nice try, dude, but that isn't a Word doc.\n\n";
        exit;
    }
    
    rename($_FILES["rtfUpload"]["tmp_name"],$target_file);
    chmod($target_file, 0755);
    chdir("/var/www/html/case/forms");
    $command = "/usr/bin/oowriter --headless --nologo --convert-to html --outdir $html_dir $target_file";
    
    $output = exec($command);
    
    $newfile = basename($target_file);
    $newfile = preg_replace('/.rtf$/','',$newfile);
    
    $htmlfile = sprintf("%s/%s.html", $html_dir, $newfile);
    $html = file_get_contents($htmlfile);
    $html = str_replace('[% data.','[% ', $html);
    $html = str_replace('[% caseid %]','[% ucn %]',$html);
    $html = str_replace('[% motiondate %]','[% dateMotionFiled %]',$html);
    $html = str_replace('[% motion %]','[% MotionTitle %]', $html);
    $html = str_replace('[% edate %]','[% event_date %]', $html);
    
    $tidyconfig = array(
        'indent' => 'auto',
        'indent-spaces' => 2,
        'markup' => true,
        'quote-nbsp' => true,
        'break-before-br' => true,
        'indent-attributes' => true,
        'uppercase-tags' => false,
        'uppercase-attributes' => false,
        'word-2000' => true,
        'drop-proprietary-attributes' => true,
        'clean' => true,
        'numeric-entities' => true,
        'quote-marks' => true,
        'quote-ampersand' => true,
        'new-inline-tags' => 'cfif, cfelse, math, mroot, mrow, mi, mn, mo, msqrt, mfrac, msubsup, munderover, munder, mover, mmultiscripts, msup, msub, mtext, mprescripts, mtable, mtr, mtd, mth',
        'new-blocklevel-tags' => 'cfoutput, cfquery',
        'new-empty-tags' => 'cfelse',
        'wrap'           => 72,
        'clean' => 'yes',
        'hide-comments' => true,
        'output-html' => true
    );
    
    // Tidy
    $tidy = new tidy;
    $tidy->parseString($html, $tidyconfig, 'utf8');
    $tidy->cleanRepair();
    
    $html = tidy_get_output($tidy);

    $query = "
        insert into
            forms (
                form_name,
                form_body
            )
            values (
                :formname,
                :html
            )
    ";
    $res = doQuery($query, $dbh, array('formname' => $formname, 'html' => $html));
} else {
    # a blank form
    $query = "
        insert into
            forms (form_name)
            values (:formname)
    ";
    $res = doQuery($query, $dbh, array('formname' => $formname));
}

if ($res) {
    echo "Form created; please edit via Edit Form on main Form Designer page.";
} else {
    echo "Error creating form $formname.";
}
?>
<p>
<input type=button value=Back onClick="window.location='index.php';">
