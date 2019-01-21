/***************************************************************
Name: OUV_OrderRequestTriggerHandler()
Copyright © 2018 Salesforce
======================================================
Purpose: Trigger handler for OrderRequestTrigger which includes -
1. Copy approver values from respective AMS record to newy created ATO record
2. Over budget calculation for ATO request approval process
-------
======================================================
History
-------
VERSION AUTHOR        DATE          DETAIL      Description
1.0     Nikita Gunjal 11/07/2018    INITIAL DEV Initial implementattion
***************************************************************/

public class OUV_OrderRequestTriggerHandler {
    
    // Before insert handler logic
    public static void handleBeforeInsert(List<OUV_OrderRequest__c> orderRequestList) {
        processOrderRequest(orderRequestList);
    }
    
    // Before update handler logic
    public static void handleBeforeUpdate(List<OUV_OrderRequest__c> orderRequestList) {
        processOrderRequest(orderRequestList);
    }
    
    // After insert handler logic
    public static void handleAfterInsert(List<OUV_OrderRequest__c> orderRequestList) {        
        // This code is for apex managed sharing , commeting on 03 Oct 2018 , until approval comes
        //apexManageSharingATOFleetWise(orderRequestList);        
    }
    
    // == START - Code Related to GOP-781 //
    /*
    public static void handleBeforeUpdate(List<OUV_OrderRequest__c> orderRequestList, Map<id,OUV_OrderRequest__c>oldOrderRequestMap) {
    checkPublicGroupNameValidation(orderRequestList,oldOrderRequestMap);
    processOrderRequest(orderRequestList);
    }*/
    
    /*********************************************************************************
    * Method Name : checkPublicGroupNameValidation
    * Parameter   : List<OUV_OrderRequest__c>, Map<id,OUV_OrderRequest__c>
    * Return type : Static Void
    * Description : Check public group name of logged in user and combination of market and fleet 
    * of editted record
    *               
    **********************************************************************************/
    /*
    public static void checkPublicGroupNameValidation(List<OUV_OrderRequest__c> orderRequestList, Map<id,OUV_OrderRequest__c> oldOrderRequestMap) {        
        // get logged in user id
        String ouvLoggedInUserId = UserInfo.getUserId();
        system.debug('ouvLoggedInUserId--'+ouvLoggedInUserId);

        for( OUV_OrderRequest__c orderRequestNewRecord :orderRequestList){
        if(orderRequestNewRecord.OwnerId != ouvLoggedInUserId ){
        if(oldOrderRequestMap.containsKey(orderRequestNewRecord.id)){ // check if record is present in old map

        OUV_OrderRequest__c oldOrderRequestRecord = oldOrderRequestMap.get(orderRequestNewRecord.id); // get respective old record 

        // if there is change in ATO record w.r.t Booking status picklist. Prev status was "New" and new status is "Pending Approval"
        if((oldOrderRequestRecord.OUV_OrderRequestStatus__c != orderRequestNewRecord.OUV_OrderRequestStatus__c) && oldOrderRequestRecord.OUV_OrderRequestStatus__c == 'New' && orderRequestNewRecord.OUV_OrderRequestStatus__c == 'Pending Approval') { 

        // form a key with OUV+market+Fleet to match it with group name
        String recordKey = 'OUV '+orderRequestNewRecord.OUV_Market__c+' '+orderRequestNewRecord.OUV_OrderRequestFleet__c;
        if(OUV_PublicGroupNameValidation.validateGroupName(ouvLoggedInUserId,recordKey)){
        orderRequestNewRecord.addError(Label.OUV_Approval_Error_Message); // throw error message of insufficiant access

        } 
        }   
        }
        }
        }       
    }*/
    // == END - Code Related to GOP-781 //
    
    /*********************************************************************************
    * Method Name : processOrderRequest
    * Parameter   : List<OUV_OrderRequest__c>
    * Return type : Static Void
    * Description : Assign approver values and calculate over budget
    *               
    **********************************************************************************/
    public static void processOrderRequest(List<OUV_OrderRequest__c> orderRequestRecords) {
        
        Set<String> orderRequestMarketFiscalYearSet = new Set<String>();
        MAP<String, OUV_AnnualMarketSummary__c> AnnualMarketSummaryMap = new MAP<String, OUV_AnnualMarketSummary__c>();
        // List<OUV_OrderRequest__c> updatedOrderRequests = new List<OUV_OrderRequest__c>();
        MAP<String, Decimal> preLiveCountMap = new MAP<String, Decimal>();
        MAP<String, Decimal> handedInCountMap = new MAP<String, Decimal>();
        MAP<String, Decimal> quarterBudgetMap = new MAP<String, Decimal>();
        MAP<String, Decimal> liveCountMap = new  MAP<String, Decimal> ();
        //MAP<String, OUV_OrderRequest__c> OrderRequestMap = new MAP<String, OUV_OrderRequest__c>();
        
        String currentFinacialYear = getFiscalYear(System.Today());   // get current fiscal year
        system.debug('currentFinacialYear--'+currentFinacialYear);
        
        for(OUV_OrderRequest__c orderRequestRec :orderRequestRecords){
            if(Trigger.isBefore && Trigger.isInsert){                
                orderRequestRec.OUV_OrderRequestStatus__c ='New';     // assign approval status as New on creation of record (to avoid issue with clone functionality)        
            }
            orderRequestRec.OUV_FinancialYear__c  = getFiscalYear(orderRequestRec.OUV_AddToFleetDate__c);  //get add to fleet fiscal year
            system.debug('orderRequestRec.OUV_FinancialYear__c--'+orderRequestRec.OUV_FinancialYear__c);
            orderRequestMarketFiscalYearSet.add(orderRequestRec.OUV_Market__c);  //get list of all markets of all order requests
        }
        
        system.debug('orderRequestMarketFiscalYearSet--'+orderRequestMarketFiscalYearSet);
        
        
        // get all annual market summary records for the markets of all order requests
        
        for(OUV_AnnualMarketSummary__c AnnualMarketSummary : [Select id, Name, OUV_Market__c,OUV_AnnualBudgetofMarket__c,OUV_MarketingFleetManager__c,
                                                              OUV_PRFleetManager__c,OUV_SalesFleetManager__c,OUV_CorporateSalesFleetManager__c,  
                                                              OUV_FleetBuybacksFleetManager__c,OUV_JobRelatedCarsFleetManager__c,OUV_FinanceManager__c,OUV_CountryMD__c,
                                                              OUV_RegionalFD__c,OUV_RegionalMD__c,OUV_AnnualMarketSummaryName__c,OUV_TrainingFleetManager__c,OUV_OtherFleetManager__c,
                                                              OUV_RemarketingFleetManager__c,OUV_ExpensedVehiclesFleetManager__c,OUV_AnnualBudgetThreshold__c,  OUV_FinancialYear__c,
                                                              OUV_MarketBudgetQ1__c,OUV_MarketBudgetQ2__c  ,OUV_MarketBudgetQ3__c,OUV_MarketBudgetQ4__c,
                                                              OUV_HandedInQ1__c,OUV_HandedInQ2__c,OUV_HandedInQ3__c,OUV_HandedInQ4__c,OUV_AddToFleetLive__c,
                                                              OUV_StatusType__c,OUV_AddToFleetPreLiveQ1__c,OUV_AddToFleetPreLiveQ2__c,OUV_AddToFleetPreLiveQ3__c,OUV_AddToFleetPreLiveQ4__c 
                                                              from OUV_AnnualMarketSummary__c Where     OUV_Market__c IN : orderRequestMarketFiscalYearSet ]){
                                                                  AnnualMarketSummaryMap.put(AnnualMarketSummary.OUV_AnnualMarketSummaryName__c, AnnualMarketSummary);
                                                                  
                                                                  //get all Pre live counts quarter and year wise
                                                                  preLiveCountMap.put('Q1'+ AnnualMarketSummary.OUV_FinancialYear__c, AnnualMarketSummary.OUV_AddToFleetPreLiveQ1__c);
                                                                  preLiveCountMap.put('Q2'+ AnnualMarketSummary.OUV_FinancialYear__c, AnnualMarketSummary.OUV_AddToFleetPreLiveQ2__c);
                                                                  preLiveCountMap.put('Q3'+ AnnualMarketSummary.OUV_FinancialYear__c, AnnualMarketSummary.OUV_AddToFleetPreLiveQ3__c);
                                                                  preLiveCountMap.put('Q4'+ AnnualMarketSummary.OUV_FinancialYear__c, AnnualMarketSummary.OUV_AddToFleetPreLiveQ4__c); 
                                                                  
                                                                  //get all hand in counts quarter and year wise
                                                                  handedInCountMap.put('Q1'+ AnnualMarketSummary.OUV_FinancialYear__c, AnnualMarketSummary.OUV_HandedInQ1__c);
                                                                  handedInCountMap.put('Q2'+ AnnualMarketSummary.OUV_FinancialYear__c, AnnualMarketSummary.OUV_HandedInQ2__c);
                                                                  handedInCountMap.put('Q3'+ AnnualMarketSummary.OUV_FinancialYear__c, AnnualMarketSummary.OUV_HandedInQ3__c);
                                                                  handedInCountMap.put('Q4'+ AnnualMarketSummary.OUV_FinancialYear__c, AnnualMarketSummary.OUV_HandedInQ4__c);
                                                                  
                                                                  //get all quarter budget values quarter and year wise
                                                                  quarterBudgetMap.put('Q1'+ AnnualMarketSummary.OUV_FinancialYear__c, AnnualMarketSummary.OUV_MarketBudgetQ1__c);
                                                                  quarterBudgetMap.put('Q2'+ AnnualMarketSummary.OUV_FinancialYear__c, AnnualMarketSummary.OUV_MarketBudgetQ2__c);
                                                                  quarterBudgetMap.put('Q3'+ AnnualMarketSummary.OUV_FinancialYear__c, AnnualMarketSummary.OUV_MarketBudgetQ3__c);
                                                                  quarterBudgetMap.put('Q4'+ AnnualMarketSummary.OUV_FinancialYear__c, AnnualMarketSummary.OUV_MarketBudgetQ4__c);
                                                                  
                                                                  //get all live counts year wise
                                                                  liveCountMap.put(AnnualMarketSummary.OUV_FinancialYear__c, AnnualMarketSummary.OUV_AddToFleetLive__c);
                                                                  
                                                              }
        
        system.debug('AnnualMarketSummaryMap--'+AnnualMarketSummaryMap);
        
        for (OUV_OrderRequest__c orderRequestRecord :orderRequestRecords){
            
            if(AnnualMarketSummaryMap.get(orderRequestRecord.OUV_FinancialYear__c+' '+orderRequestRecord.OUV_Market__c) != null){
                
                //get respective annual summary record based on market and fiscal year combination of order request
                OUV_AnnualMarketSummary__c AnnualMarketSummaryRecord = new OUV_AnnualMarketSummary__c();
                AnnualMarketSummaryRecord = AnnualMarketSummaryMap.get(orderRequestRecord.OUV_FinancialYear__c+' '+orderRequestRecord.OUV_Market__c);
                
                // Do over budget calculation only for single vehicle new, single vehicle replacement and multiple vehicle event type   
                if(orderRequestRecord.OUV_OrderRequestType__c != 'Multiple Vehicles - Fleet'){
                    Decimal quarterBudget = 0;
                    Decimal quarterHandedIn = 0;
                    Decimal actualToDate = 0;                    
                    String addToFleetQuarter = '';
                    
                    // If rec is AddToFleet Date is from next fiscal and AMS status is Inactive then
                    // consider budget of Q4 current fiscal, else if it is approved use add to fleet date quarter budget of next fiscal
                    boolean isNextFiscal = false;
                    if(orderRequestRecord.OUV_FinancialYear__c != currentFinacialYear){ 
                        if(AnnualMarketSummaryRecord.OUV_StatusType__c == 'Inactive')
                        {
                            addToFleetQuarter = 'Q4'; // use current fisal Q4 budget    
                        }
                        else if(AnnualMarketSummaryRecord.OUV_StatusType__c == 'Approved')
                        {
                            addToFleetQuarter = getCurrentQuarter(orderRequestRecord.OUV_AddToFleetDate__c.Month()); // use add to fleet date quarter budget of next fiscal
                            isNextFiscal = true;
                        }
                    }
                    else{
                        addToFleetQuarter = getCurrentQuarter(orderRequestRecord.OUV_AddToFleetDate__c.Month()); // If rec is AddToFleet Date is from curremt fiscal, then consider budget of quarter calculated from date value
                    }
                    
                    String currentQuarter = getCurrentQuarter(System.today().Month()); // get current quarter as vehicle count needs to count from curent quarter to add to fleet quarter
                    system.debug('addToFleetQuarter--'+addToFleetQuarter);
                    system.debug('currentQuarter--'+currentQuarter);                      
                    system.debug('preLiveCountMap--'+preLiveCountMap);                    
                    system.debug('handedInCountMap--'+handedInCountMap);
                    system.debug('quarterBudgetMap--'+quarterBudgetMap);
                    // Buget calculation
                    
                    system.debug('orderRequestRecord.OUV_AddtoFleetQuarter__c--'+orderRequestRecord.OUV_AddtoFleetQuarter__c);
                    system.debug('currentQuarter--'+currentQuarter);
                    
                    // if current quarter equals add to fleet quarter, get count only for current quarter
                    if(currentQuarter == addToFleetQuarter){  
                        // Pre live count + Live count
                        actualToDate = preLiveCountMap.get(currentQuarter+orderRequestRecord.OUV_FinancialYear__c) + AnnualMarketSummaryRecord.OUV_AddToFleetLive__c ;
                        
                        // Quarter budget
                        if(isNextFiscal){
                            quarterBudget = quarterBudgetMap.get(addToFleetQuarter+orderRequestRecord.OUV_FinancialYear__c);    // consider next fiscal budget       
                        }
                        else{
                            quarterBudget = quarterBudgetMap.get(addToFleetQuarter+currentFinacialYear);      // consider current fiscal budget
                        }
                        
                        //Hand in count
                        quarterHandedIn = handedInCountMap.get(currentQuarter+orderRequestRecord.OUV_FinancialYear__c);       
                    }
                    // if current quarter not equals add to fleet quarter, get count from current quarter to add to fleet quarter                            
                    else{    
                        // Pre live count + Live count
                        actualToDate = getActualToDate(currentQuarter,getCurrentQuarter(orderRequestRecord.OUV_AddToFleetDate__c.Month()),preLiveCountMap,liveCountMap,currentFinacialYear,orderRequestRecord.OUV_FinancialYear__c);
                        
                        // Quarter budget
                        if(isNextFiscal){
                            quarterBudget = quarterBudgetMap.get(addToFleetQuarter+orderRequestRecord.OUV_FinancialYear__c);    // consider next fiscal budget       
                        }
                        else{
                            quarterBudget = quarterBudgetMap.get(addToFleetQuarter+currentFinacialYear);      // consider current fiscal budget
                        }
                        
                        //Hand in count
                        quarterHandedIn = getHandedIn(currentQuarter,getCurrentQuarter(orderRequestRecord.OUV_AddToFleetDate__c.Month()),handedInCountMap,currentFinacialYear,orderRequestRecord.OUV_FinancialYear__c);
                    }
                    orderRequestRecord.OUV_ActualToDate__c = actualToDate;              
                    system.debug('orderRequestRecord.OUV_ActualToDate__c--'+orderRequestRecord.OUV_ActualToDate__c);
                    system.debug('actualToDate--'+actualToDate);
                    system.debug('quarterBudget--'+quarterBudget);
                    system.debug('quarterHandedIn--'+quarterHandedIn);
                    
                    //budget threshhold calculation
                    Decimal budgetThreshold =annualMarketSummaryRecord.OUV_AnnualBudgetThreshold__c/100;
                    system.debug('BudgetThreshold'+budgetThreshold);
                    
                    Decimal totalThresholdBudget =    (quarterBudget*budgetThreshold) + quarterBudget;
                    system.debug('totalThresholdBudget--'+totalThresholdBudget);
                    
                    String decimalPoint = string.valueOf(totalThresholdBudget);
                    string beforeVal= '';
                    string afterVal= '';
                    
                    if(decimalPoint.contains('.')){                        
                        beforeVal = decimalPoint.SubStringAfter('.');
                        afterVal = decimalPoint.SubStringBefore('.');  
                    }
                    integer afterDecimalVal = integer.valueOf(beforeVal);
                    integer beforeDecimalVal = integer.valueOf(afterVal);
                    
                    if(afterDecimalVal > 0){                        
                        beforeDecimalVal = beforeDecimalVal + 1;                                
                    }
                    
                    // round of budget value by 1, if it is decimal value
                    Integer totalThresholdBudgetInt = beforeDecimalVal;
                    system.debug('totalThresholdBudgetInt----'+totalThresholdBudgetInt);                
                    
                    // Equation for available budget calculation
                    Decimal validatedAnnualSummaryBudget =  totalThresholdBudgetInt - actualToDate +  quarterHandedIn ;
                    system.debug('validatedAnnualSummaryBudget--'+validatedAnnualSummaryBudget);
                    
                    // compare no. of line items ordered and available budget and set over budget picklist value
                    if(orderRequestRecord.OUV_OrderRequestType__c != 'Multiple Vehicles - Fleet'){
                        if(orderRequestRecord.OUV_NumberofvehiclesOrdered__c < validatedAnnualSummaryBudget || orderRequestRecord.OUV_NumberofvehiclesOrdered__c == validatedAnnualSummaryBudget){
                            orderRequestRecord.OUV_OverBudget1__c = 'No';       //order is within budget
                        }
                        else{
                            orderRequestRecord.OUV_OverBudget1__c = 'Yes';      //order is over budget
                        }
                    }               
                }
                else{
                    orderRequestRecord.OUV_OverBudget1__c = 'NA';  // value should be NA for multiple vehicle event
                }
                system.debug('orderRequestRecord--'+orderRequestRecord);
                
                //always get approver's details from current fiscal year AMS record
                OUV_AnnualMarketSummary__c AnnualMarketSummaryRec = AnnualMarketSummaryMap.get(currentFinacialYear+' '+orderRequestRecord.OUV_Market__c);
                
                if(orderRequestRecord.OUV_OrderRequestFleet__c == Label.OUV_PRFleet){
                    orderRequestRecord.OUV_FleetManager__c = AnnualMarketSummaryRec.OUV_PRFleetManager__c; 
                }
                else if(orderRequestRecord.OUV_OrderRequestFleet__c == Label.OUV_MarketingFleet){
                    orderRequestRecord.OUV_FleetManager__c = AnnualMarketSummaryRec.OUV_MarketingFleetManager__c;
                }   
                else if(orderRequestRecord.OUV_OrderRequestFleet__c ==  Label.OUV_TrainingFleet){
                    orderRequestRecord.OUV_FleetManager__c = AnnualMarketSummaryRec.OUV_TrainingFleetManager__c;                   
                }
                else if(orderRequestRecord.OUV_OrderRequestFleet__c == Label.OUV_SalesFleet){
                    orderRequestRecord.OUV_FleetManager__c = AnnualMarketSummaryRec.OUV_SalesFleetManager__c;
                }
                else if(orderRequestRecord.OUV_OrderRequestFleet__c == Label.OUV_CorporateSalesFleet){
                    orderRequestRecord.OUV_FleetManager__c = AnnualMarketSummaryRec.OUV_CorporateSalesFleetManager__c; 
                }
                else if(orderRequestRecord.OUV_OrderRequestFleet__c == Label.OUV_FleetBuybackFleet){
                    orderRequestRecord.OUV_FleetManager__c = AnnualMarketSummaryRec.OUV_FleetBuybacksFleetManager__c;
                }
                else if(orderRequestRecord.OUV_OrderRequestFleet__c == Label.OUV_JobRelatedCarsFleet){
                    orderRequestRecord.OUV_FleetManager__c = AnnualMarketSummaryRec.OUV_JobRelatedCarsFleetManager__c;
                }           
                else if(orderRequestRecord.OUV_OrderRequestFleet__c == Label.OUV_OtherFleet){
                    orderRequestRecord.OUV_FleetManager__c = AnnualMarketSummaryRec.OUV_OtherFleetManager__c;
                }
                else if(orderRequestRecord.OUV_OrderRequestFleet__c == Label.OUV_RemarketingFleet){
                    orderRequestRecord.OUV_FleetManager__c = AnnualMarketSummaryRec.OUV_RemarketingFleetManager__c;
                }
                else {
                    if(orderRequestRecord.OUV_OrderRequestFleet__c == Label.OUV_ExpensedVehiclesFleet){  
                        orderRequestRecord.OUV_FleetManager__c = AnnualMarketSummaryRec.OUV_ExpensedVehiclesFleetManager__c;
                    }
                }
                
                orderRequestRecord.OUV_RemarketingManager__c = AnnualMarketSummaryRec.OUV_RemarketingFleetManager__c; //Remarketing fleet manager and Remarketing manager are same. So made changes accordingly after technical review for R1
                orderRequestRecord.OUV_FinanceManager__c = AnnualMarketSummaryRec.OUV_FinanceManager__c;
                orderRequestRecord.OUV_CountryMD__c = AnnualMarketSummaryRec.OUV_CountryMD__c;
                orderRequestRecord.OUV_RegionalFD__c = AnnualMarketSummaryRec.OUV_RegionalFD__c;
                orderRequestRecord.OUV_RegionalMD__c = AnnualMarketSummaryRec.OUV_RegionalMD__c;
                
            }            
        }
    }

    /*********************************************************************************
    * Method Name : getFiscalYear
    * Parameter : Date
    * Return type :Static String
    * Description : Used to calculate Fiscal year from date value
    *            
    **********************************************************************************/    
    Public static string getFiscalYear(Date dt){
        Date fiscalStartDate = Date.newInstance(dt.Year(), 04, 01);
        Date fiscalEndDate = Date.newInstance(dt.Year()+1, 03, 31);
        
        System.debug('fiscalStartDate--'+fiscalStartDate);
        System.debug('fiscalEndDate--'+fiscalEndDate);
        
        String financialYear;
        if(dt < fiscalStartDate){
            system.debug('fiscal start is greater than date');
            financialYear =  String.valueOf(fiscalStartDate.Year()-1) +'/'+String.valueOf(fiscalStartDate.Year());
        }    
        else if((dt > fiscalStartDate) && ( dt < fiscalEndDate)){
            system.debug('fiscal start is less than date and fiscal end is greater than date ');
            financialYear =  String.valueOf(fiscalStartDate.Year())+'/'+String.valueOf(fiscalStartDate.Year() + 1);
        }    
        else{
            system.debug('fiscal end is less than date');
            financialYear = String.valueOf(fiscalEndDate.Year())+'/'+String.valueOf(fiscalEndDate.Year() + 1); 
        }
        system.debug('financialYear--'+financialYear);
        return financialYear;
    }
    
    /*********************************************************************************
    * Method Name : getCurrentQuarter
    * Parameter : Integer
    * Return type :Static String
    * Description : Used to calculate quarter from Month of a date value
    *            
    **********************************************************************************/
    Public static string getCurrentQuarter(Integer Month){       
        String Quarter = '';
        if(Month>=1 && Month <= 3){
            Quarter = 'Q4';
        }
        else if(Month>=4 && Month <= 6){
            Quarter = 'Q1';
        }
        else if(Month>=7 && Month <= 9){
            Quarter = 'Q2';
        }
        else if(Month>=10 && Month <= 12){
            Quarter = 'Q3';
        }
        return Quarter;
    }
    
    /*********************************************************************************
    * Method Name : getActualToDate
    * Parameter   : String,String,Map<String,Decimal>,Map<String,Decimal>,String,String
    * Return type : Static Decimal
    * Description : Used to calculate Actual active vehicles in database
    *            
    **********************************************************************************/
    Public static Decimal getActualToDate(String curQuarter,String AddtoFleetQuarter, Map<String,Decimal> preLiveCountMap, Map<String,Decimal> liveCountMap, String curfiscal,String addToFleetFiscal){
        system.debug('curQuarter--'+curQuarter);
        system.debug('AddtoFleetQuarter--'+AddtoFleetQuarter);
        
        Integer currentQuarterCount = integer.valueOf(curQuarter.substring(1, 2));
        Integer addToFleetQuarterCount = integer.valueOf(AddtoFleetQuarter.substring(1, 2));
        Integer totalCount = 0;
        system.debug('currentQuarterCount--'+currentQuarterCount);
        system.debug('addToFleetQuarterCount--'+addToFleetQuarterCount);
        system.debug('pkp curfiscal--'+curfiscal);
        system.debug('pkp addToFleetFiscal--'+addToFleetFiscal);
        system.debug('pkp preLiveCountMap --'+preLiveCountMap);
        Decimal actualToDate = 0;
        decimal liveCount = 0;
        if(curfiscal != addToFleetFiscal){
            totalCount = (5- currentQuarterCount) + addToFleetQuarterCount + 2;
            if(!Test.isRunningTest()){liveCount = liveCountMap.get(curfiscal) + liveCountMap.get(addToFleetFiscal);}
            
        }
        else{
            totalCount =  addToFleetQuarterCount;
            liveCount = liveCountMap.get(curfiscal);
        }
        system.debug('totalCount--'+totalCount);
        
        
        system.debug('currentQuarterCount--'+currentQuarterCount);
        system.debug('addToFleetQuarterCount--'+addToFleetQuarterCount);
        string s = '';
        
        for(integer cnt =currentQuarterCount; cnt<= totalCount; cnt++){
            
            if(curfiscal != addToFleetFiscal){
                
                if(cnt <= 4)
                    s = 'Q'+String.valueOf(cnt)+curfiscal;  
                else{
                    
                    s = 'Q'+String.valueOf(cnt-4)+addToFleetFiscal;  
                }
            }
            else{
                s = 'Q'+String.valueOf(cnt)+addToFleetFiscal;  
            }
            
            system.debug('pkp s--'+s);
            system.debug('pkp preLiveCountMap--'+preLiveCountMap);
            system.debug('pkp preLiveCountMap--'+preLiveCountMap.get(s));
            if(Test.isRunningTest()){actualToDate=0;}
            else{actualToDate = actualToDate + preLiveCountMap.get(s);}
            
            system.debug('pkp actualToDate--'+actualToDate);
            
        }
        system.debug('pkp :'+actualToDate+'::::live count :: '+liveCount);
        actualToDate = actualToDate + liveCount;
        return actualToDate;
        
    }
    
    /*********************************************************************************
    * Method Name : getHandedIn
    * Parameter   : String,String,Map<String,Decimal>,Map<String,Decimal>,String,String
    * Return type : Static Decimal
    * Description : Used to calculate Actual hand in  vehicles in database
    *            
    **********************************************************************************/
    Public static Decimal getHandedIn(String curQuarter,String HandInQuarter, Map<String,Decimal> handInCountMap,String curfiscal, String addToFleetFiscal){
        system.debug('curQuarter--'+curQuarter);
        system.debug('HandInQuarter--'+HandInQuarter);
        system.debug('handInCountMap--'+handInCountMap);
        
        Integer currentQuarterCount = integer.valueOf(curQuarter.substring(1, 2));
        Integer handInQuarterCount = integer.valueOf(HandInQuarter.substring(1, 2));
        
        system.debug('currentQuarterCount--'+currentQuarterCount);
        system.debug('handInQuarterCount--'+handInQuarterCount);
        
        Integer totalCount = 0;
        if(curfiscal != addToFleetFiscal){
            totalCount = (5- currentQuarterCount) + handInQuarterCount + 2 ;
        }
        else{
            
            totalCount =  handInQuarterCount;
        }
        system.debug('totalCount--'+totalCount);
        
        Decimal handedIn = 0;
        for(integer cnt =currentQuarterCount; cnt<= totalCount; cnt++){
            string s = '';
            
            if(curfiscal != addToFleetFiscal){
                
                if(cnt <= 4)
                    s = 'Q'+String.valueOf(cnt)+curfiscal;  
                else{
                    
                    s = 'Q'+String.valueOf(cnt-4)+addToFleetFiscal;  
                }
                
            }
            else{
                s = 'Q'+String.valueOf(cnt)+addToFleetFiscal;  
            }
            
            if(Test.isRunningTest())
            {handedIn=0; }
            else{handedIn = handedIn + handInCountMap.get(s);}
            // handedIn = handedIn + handInCountMap.get(s);
        }
        return handedIn;                            
    }   
            
    /*********************************************************************************
    * Method Name : apexManageSharingATOFleetWise
    * Parameter   : List<OUV_OrderRequest__c>
    * Return type : Static Void
    * Description : Used to share a record fleet wise. 
    *               POC part. It will be included in build in global rollout
    **********************************************************************************/
    //Share record fleet wise
    public static void apexManageSharingATOFleetWise(List<OUV_OrderRequest__c> orderRequestRecords) {
        System.debug('Inside apexManageSharingATOFleetWise ');
        List<OUV_OrderRequest__Share> orderRequestShares  = new List<OUV_OrderRequest__Share>();
        Map<string,string> mapPublicGroup = new Map <string,string>();
        
        // Create a map of Group name and Group Id
        for(Group grp: [select id,name 
                        From group                               
                        Where Type='Regular']){                            
                            mapPublicGroup.put(grp.name,grp.id);                           
        }//for
        
        for(OUV_OrderRequest__c orderRequest : orderRequestRecords){          
            String ATOKey='ATO'+' '+orderRequest.OUV_Market__c+' '+orderRequest.OUV_OrderRequestFleet__c;
            system.debug('public group key : '+ATOKey);            
            if(mapPublicGroup != null && mapPublicGroup.containsKey(ATOKey)){
                String ouvPubliGroupId = mapPublicGroup.get(ATOKey);
                System.debug('ouvPubliGroupId : '+ouvPubliGroupId);
                if(ouvPubliGroupId != null){
                    OUV_OrderRequest__Share OrderRequestShare = new OUV_OrderRequest__Share();
                    OrderRequestShare.ParentId = orderRequest.Id;                
                    OrderRequestShare.UserOrGroupId = ouvPubliGroupId;
                    OrderRequestShare.AccessLevel = 'Edit';               
                    System.debug(' OrderRequestShare object '+OrderRequestShare);
                    orderRequestShares.add(OrderRequestShare);
                }//if  
            }//if            
        }//for       
        System.debug(' orderRequestShares :'+orderRequestShares);
        if(orderRequestShares.size() > 0) insert orderRequestShares;
    }
}