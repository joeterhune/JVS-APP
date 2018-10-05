<BulkGetFilingStatusRequest xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns="urn:oasis:names:tc:legalxml-courtfiling:schema:xsd:FilingStatusQueryMessage-4.0:FilingStatusQueryMessage" >
        <FilingStatusQueryMessage  xmlns:ecf="urn:oasis:names:tc:legalxml-courtfiling:schema:xsd:CommonTypes-4.0" xmlns:nc="http://niem.gov/niem/niem-core/2.0" xmlns:d4p1="http://niem.gov/niem/structures/2.0">
            <ecf:QuerySubmitter>
                <ecf:EntityPerson d4p1:id="FILER">
                    <nc:PersonName>
                        <nc:PersonGivenName>{$data.firstname}</nc:PersonGivenName>
                        <nc:PersonSurName>{$data.lastname}</nc:PersonSurName>
                        <nc:PersonFullName>{$data.firstname} {$data.lastname}</nc:PersonFullName>
                    </nc:PersonName>
                    <nc:PersonOtherIdentification>
                        <nc:IdentificationID>{$data.logonname}</nc:IdentificationID>
                        <nc:IdentificationCategoryText>FLEPORTAL_LOGONNAME</nc:IdentificationCategoryText>
                    </nc:PersonOtherIdentification>
                    <nc:PersonOtherIdentification>
                        <nc:IdentificationID>{$data.password}</nc:IdentificationID>
                        <nc:IdentificationCategoryText>FLEPORTAL_PASSWORD</nc:IdentificationCategoryText>
                    </nc:PersonOtherIdentification>
                    <nc:PersonOtherIdentification>
                        <nc:IdentificationID>{$data.bar_id}</nc:IdentificationID>
                        <nc:IdentificationCategoryText>BAR_NUMBER</nc:IdentificationCategoryText>
                    </nc:PersonOtherIdentification>
                </ecf:EntityPerson>
            </ecf:QuerySubmitter>
        
            <nc:DocumentIdentification>
                <nc:IdentificationID>94144</nc:IdentificationID>
                <nc:IdentificationCategoryText>FLEPORTAL_FILING_ID</nc:IdentificationCategoryText>
            </nc:DocumentIdentification>
        </FilingStatusQueryMessage>
</BulkGetFilingStatusRequest>