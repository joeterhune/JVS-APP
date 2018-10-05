<BulkGetFilingReviewResultRequest xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
                                  xmlns="urn:oasis:names:tc:legalxml-courtfiling:wsdl:WebServiceMessagingProfile-Definitions-4.0">
    {foreach $filings as $filingID}<FilingStatusQueryMessage xmlns="urn:oasis:names:tc:legalxml-courtfiling:schema:xsd:FilingStatusQueryMessage-4.0">
        <SendingMDELocationID xmlns="urn:oasis:names:tc:legalxml-courtfiling:schema:xsd:CommonTypes-4.0">
            <IdentificationID xmlns="http://niem.gov/niem/niem-core/2.0">URL/UNIQUE IDENTIFIER OF APPLICATION SENDING THIS REQUEST </IdentificationID>
            <IdentificationCategoryText xmlns="http://niem.gov/niem/niem-core/2.0">FLEPORTAL</IdentificationCategoryText>
        </SendingMDELocationID>
            <SendingMDEProfileCode xmlns="urn:oasis:names:tc:legalxml-courtfiling:schema:xsd:CommonTypes-4.0">urn:oasis:names:tc:legalxml-courtfiling:schema:xsd:WebServicesMessaging-2.0</SendingMDEProfileCode>
            <QuerySubmitter xmlns="urn:oasis:names:tc:legalxml-courtfiling:schema:xsd:CommonTypes-4.0">
            <EntityPerson xmlns:a="http://niem.gov/niem/structures/2.0" a:id="FILER">
                <PersonOtherIdentification xmlns="http://niem.gov/niem/niem-core/2.0">
                    <IdentificationID>{$adminLogin}</IdentificationID>
                    <IdentificationCategoryText>FLEPORTAL_LOGONNAME</IdentificationCategoryText>
                </PersonOtherIdentification>
                <PersonOtherIdentification xmlns="http://niem.gov/niem/niem-core/2.0">
                    <IdentificationID>{$adminPassword}</IdentificationID>
                    <IdentificationCategoryText>FLEPORTAL_PASSWORD</IdentificationCategoryText>
                </PersonOtherIdentification>
            </EntityPerson>
        </QuerySubmitter>
        
        <DocumentIdentification xmlns="http://niem.gov/niem/niem-core/2.0">
            <IdentificationID>{$filingID}</IdentificationID>
            <IdentificationCategoryText>FLEPORTAL_FILING_ID</IdentificationCategoryText>
        </DocumentIdentification>
    </FilingStatusQueryMessage>
    {/foreach}
</BulkGetFilingReviewResultRequest>
