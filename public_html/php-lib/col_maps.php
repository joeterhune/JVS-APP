<?php

$colMaps = array (
    'CaseNumber' => array(
        'colName' => 'CaseNumber',
        'colHeader' => 'Case #',
        'filterPlaceholder' => 'Part of case #',
        'type' => 'L'
    ),
    'CaseStyle' => array (
        'colName' => 'CaseStyle',
        'colHeader' => 'Name',
        'filterPlaceholder' => 'Part of case style',
        'cellClass' => 'caseStyle',
        'type' => 'I'
    ),
    'DOB' => array(
        'colName' => 'DOB',
        'filterPlaceholder' => 'Date',
        'filter-type' => 'filter-select filter-match',
        'cellClass' => 'dateCol',
        'type' => 'D'
    ),
    'FileDate' => array(
        'colName' => 'FileDate',
        'colHeader' => 'Initial File',
        'filterPlaceholder' => 'Date',
        'filter-type' => 'filter-select',
        'cellClass' => 'dateCol',
        'type' => 'D'
    ),
    'CaseAge' => array(
        'colHeader' => 'Age',
        'colName' => 'CaseAge',
        'filterPlaceholder' => 'Select Range',
        'cellClass' => 'medNum',
        'type' => 'D'
    ),
    'CaseType' => array(
        'colHeader' => 'Case<br>Type',
        'colName' => 'CaseType',
        'filterPlaceholder' => 'Type',
        'filter-type' => 'filter-select',
        'cellClass' => 'medNum',
        'type' => 'C'
    ),
    'CaseStatus' => array(
        'colName' => 'CaseStatus',
        'colHeader' => 'Status',
        'filterPlaceholder' => 'Status',
        'filter-type' => 'filter-select',
        'cellClass' => 'medNum',
        'type' => 'I'
    ),
    'LastActivity' => array(
        'colName' => 'LastActivity',
        'colHeader' => 'Last<br>Activity<br>Date',
        'filterPlaceholder' => 'Date',
        'filter-type' => 'filter-select',
        'cellClass' => 'dateCol',
        'type' => 'D'
    ),
    'NumCharges' => array(
        'colName' => 'NumCharges',
        'colHeader' => '# of Charges',
        'filterPlaceholder' => 'Count',
        'filter-type' => 'filter-select',
        'cellClass' => 'smallNum',
        'type' => 'D'
    ),
    'Charges' => array(
        'colName' => 'Charges',
        'filterPlaceholder' => 'Part of charge',
        'type' => 'I'
    ),
    'Event Code' => array(
        'colName' => 'FarthestEventCode',
        'filterPlaceholder' => 'Code',
        'filter-type' => 'filter-select',
        'cellClass' => 'eventCode'
    ),
    'Latest / Farthest Event' => array(
        'colName' => 'FarthestEvent',
        'filterPlaceholder' => 'Date',
        'filter-type' => 'filter-select',
        'cellClass' => 'dateCol'
    ),
    'MergedNotesFlags' => array(
        'colName' => 'MergedNotesFlags',
        'colHeader' => 'Flags/Most Recent Note',
        'filterPlaceholder' => 'Part of flag or note',
        'cellClass' => 'caseNote',
        'type' => 'I'
    ),
    'DivisionID' => array(
        'colName' => 'DivisionID',
        'colHeader' => 'Div',
        'filterPlaceholder' => 'Div',
        'filter-type' => 'filter-select',
        'cellClass' => 'divCol',
        'type' => 'C'
    ),
    'LastDocketCode' => array(
        'colName' => 'LastDocketCode',
        'colHeader' => 'Last<br>Activity',
        'filterPlaceholder' => 'Code',
        'filter-type' => 'filter-select',
        'cellClass' => 'eventCode',
        'type' => 'C'
    ),
    'Sex' => array(
        'colName' =>'Sex',
        'filterPlaceholder' => 'Sex',
        'filter-type' => 'filter-select',
        'cellClass' => 'yesno',
        'type' => 'C'
    ),
    'InJail' => array(
        'colName' => 'InJail',
        'colHeader' => 'In<br>Jail',
        'filterPlaceholder' => 'Select',
        'filter-type' => 'filter-select',
        'cellClass' => 'yesno',
        'type' => 'C'
    ),
    'DaysServed' => array(
        'colName' => 'DaysServed',
        'colHeader' => 'Days<br>Served',
        'filterPlaceholder' => 'Days',
        'cellClass' => 'smallNum',
        'type' => 'D'
    ),
    'CaseAge' => array(
        'colName' => 'CaseAge',
        'colHeader' => 'Case<br>Age',
        'filterPlaceholder' => 'Age',
        'cellClass' => 'medNum',
        'type' => 'D'
    ),
    'ChargeCount' => array(
        'colName' => 'ChargeCount',
        'colHeader' => '# of<br>Charges',
        'filterPlaceholder' => 'Count',
        'filter-type' => 'filter-select',
        'cellClass' => 'smallNum'
    ),
    'TopChargeDesc' => array(
        'colName'=> 'TopChargeDesc',
        'colHeader' => 'Highest<br>Charge<br>Degree',
        'filterPlaceholder' => 'Select Degree',
        'filter-type' => 'filter-select',
        'cellClass' => 'shortText',
        'type' => 'I'
    ),
    'MostRecentEventDate' => array(
        'colName' => 'MostRecentEventDate',
        'colHeader' => 'Most<br>Recent<br>Event Date',
        'filterPlaceholder' => 'Date',
        'filter-type' => 'filter-select',
        'cellClass' => 'dateCol',
        'type' => 'D'
    ),
    'MostRecentEventType' => array(
        'colName' => 'MostRecentEventType',
        'colHeader' => 'Most Recent<br>Event Type',
        'filterPlaceholder' => 'Type',
        'filter-type' => 'filter-select',
        'type' => 'I'
    ),
    'FarthestEventDate' => array(
        'colName' => 'FarthestEventDate',
        'colHeader' => 'Farthest Event<br>Date',
        'filterPlaceholder' => 'Date',
        'filter-type' => 'filter-select',
        'cellClass' => 'dateCol',
        'type' => 'D'
    ),
    'FarthestEventType' => array(
        'colName' => 'FarthestEventCode',
        'colHeader' => 'Farthest Event<br>Type',
        'filterPlaceholder' => 'Type',
        'filter-type' => 'filter-select',
        'cellClass' => 'eventCode',
        'type' => 'C'
    )
);

?>