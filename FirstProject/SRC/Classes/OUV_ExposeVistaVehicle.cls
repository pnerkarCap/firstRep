@RestResource(urlMapping='/v1/getVistaVehicles/*')

global with sharing class OUV_ExposeVistaVehicle{
    @HttpGet
    global static list<Asset> fetchVistaVehicle(){
        RestRequest req = RestContext.request;
        RestResponse res = Restcontext.response;
        //fetch all vista vehicles
        List<Asset> listAsset =[Select OUV_Order_Number__c,
                                       OUV_ABS_Date__c, 
                                       OUV_Brochure_Model_Code__c,
                                       OUV_Build_Date__c,
                                       OUV_Delivery_Date__c,
                                       OUV_Derivative_Pack_Code__c,
                                       OUV_Derivative_Pack_Description__c,
                                       OUV_Emissions_Efficiency__c,
                                       OUV_Full_Vin__c,
                                       OUV_Local_Option__c,
                                       OUV_Market__c,
                                       OUV_Market_Code__c,
                                       OUV_Market_Description__c,
                                       OUV_Model_Year_Description__c,
                                       OUV_Notes__c,
                                       OUV_Option__c,
                                       OUV_Paint_Code__c,
                                       OUV_Paint_Description__c,
                                       OUV_Price__c,
                                       OUV_Product_Description__c,
                                       OUV_Region__c,
                                       OUV_Short_VIN__c,
                                       OUV_Status_Code__c,
                                       OUV_Status_Description__c,
                                       OUV_Transmission_Code__c,
                                       OUV_Transmission_Description__c,
                                       OUV_Trim_Code__c,
                                       OUV_Trim_Description__c,
                                       OUV_Type_of_Sale_Code__c,
                                       OUV_Type_of_Sale_Description__c
                                From Asset
                                Where OUV_Order_Number__c != null ];
        return listAsset ;
    }
}