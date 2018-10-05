<?php

$colMaps = array (
    'Case #' => array(
        'colName' => 'CaseNumber',
        'filterPlaceholder' => 'Part of case #'
    ),
    'Name' => array (
        'colName' => 'CaseStyle',
        'filterPlaceholder' => 'Part of case style',
        'cellClass' => 'caseStyle'
    ),
    'DOB' => array(
        'colName' => 'DOB',
        'filterPlaceholder' => 'Date',
        'filter-type' => 'filter-select filter-match',
        'cellClass' => 'dateCol'
    ),
    'Initial File' => array(
        'colName' => 'FileDate',
        'filterPlaceholder' => 'Date',
        'filter-type' => 'filter-select',
        'cellClass' => 'dateCol'
    ),
    'Age' => array(
        'colName' => 'CaseAge',
        'filterPlaceholder' => 'Select Range',
        'cellClass' => 'medNum'
    ),
    'Type' => array(
        'colName' => 'CaseType',
        'filterPlaceholder' => 'Type',
        'filter-type' => 'filter-select',
        'cellClass' => 'medNum'
    ),
    'Status' => array(
        'colName' => 'CaseStatus',
        'filterPlaceholder' => 'Status',
        'filter-type' => 'filter-select',
        'cellClass' => 'medNum'
    ),
    'Last Activity' => array(
        'colName' => 'LastActivity',
        'filterPlaceholder' => 'Date',
        'filter-type' => 'filter-select',
        'cellClass' => 'dateCol'
    ),
    '# of Charges' => array(
        'colName' => 'ChargeCount',
        'filterPlaceholder' => 'Count',
        'filter-type' => 'filter-select',
        'cellClass' => 'smallNum'
    ),
    'Charges' => array(
        'colName' => 'Charges',
        'filterPlaceholder' => 'Part of charge'
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
    'Flags/Most Recent Note' => array(
        'colName' => 'FlagsNotes',
        'filterPlaceholder' => 'Part of flag or note',
        'cellClass' => 'caseNote'
    ),
    'Div' => array(
        'colName' => 'DivisionID',
        'filterPlaceholder' => 'Div',
        'filter-type' => 'filter-select',
        'cellClass' => 'divCol'
    ),
    'Last Activity Date' => array(
        'colName' => 'LastActivityDate',
        'filterPlaceholder' => 'Date',
        'filter-type' => 'filter-select',
        'cellClass' => 'dateCol'
    ),
    'Sex' => array(
        'colName' =>'Sex',
        'filterPlaceholder' => 'Sex',
        'filter-type' => 'filter-select',
        'cellClass' => 'yesno'
    ),
    'In<br>Jail' => array(
        'colName' => 'InJail',
        'filterPlaceholder' => 'Select',
        'filter-type' => 'filter-select',
        'cellClass' => 'yesno'
    ),
    'Days<br>Served' => array(
        'colName' => 'DaysServed',
        'filterPlaceholder' => 'Days',
        'cellClass' => 'smallNum'
    ),
    'Case<br>Type' => array(
        'colName' => 'CaseType',
        'filterPlaceholder' => 'Type',
        'filter-type' => 'filter-select',
        'cellClass' => 'medNum'
    ),
    'Case<br>Age' => array(
        'colName' => 'CaseAge',
        'filterPlaceholder' => 'Age',
        'cellClass' => 'medNum'
    ),
    '# of<br>Charges' => array(
        'colName' => 'ChargeCount',
        'filterPlaceholder' => 'Count',
        'filter-type' => 'filter-select',
        'cellClass' => 'smallNum'
    ),
    'Highest<br>Charge<br>Degree' => array(
        'colName'=> 'HighestDegree',
        'filterPlaceholder' => 'Select Degree',
        'filter-type' => 'filter-select',
        'cellClass' => 'shortText'
    ),
    'Most<br>Recent<br>Event Date' => array(
        'colName' => 'MostRecentEventDate',
        'filterPlaceholder' => 'Date',
        'filter-type' => 'filter-select',
        'cellClass' => 'dateCol'
    ),
    'Most Recent<br>Event Type' => array(
        'colName' => 'MostRecentEventType',
        'filterPlaceholder' => 'Type',
        'filter-type' => 'filter-select'
    ),
    'Farthest<br>Event' => array(
        'colName' => 'FarthestEvent',
        'filterPlaceholder' => 'Date',
        'filter-type' => 'filter-select',
        'cellClass' => 'dateCol'
    ),
    'Farthest Event<br>Type' => array(
        'colName' => 'FarthestEventCode',
        'filterPlaceholder' => 'Type',
        'filter-type' => 'filter-select'
    )
);

?>