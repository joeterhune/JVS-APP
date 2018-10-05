<?xml version="1.0"?>
<RetrieveCaseDocsInput xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="http://www.csisoft.com/2010/1.0/RetrieveCaseDocsInput.xsd">
    <UserID>{$data.user_id}</UserID>
    <Password>{$data.user_password}</Password>
    {if isset($data.casenum)}<CaseNumber>{$data.casenum}</CaseNumber>
    {else if isset($data.objectid)}<ObjectID>{$data.objectid}</ObjectID>{/if}
</RetrieveCaseDocsInput>
