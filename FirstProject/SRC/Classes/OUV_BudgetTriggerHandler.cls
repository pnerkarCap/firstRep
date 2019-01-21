/***************************************************************
Name: OUV_BudgetTriggerHandler()
Copyright © 2018 Salesforce
======================================================
Purpose: Trigger handler for OUV_BudgetTrigger
-------To provide edit access to budget record based fleet public group
======================================================
History
-------
VERSION AUTHOR              DATE            DETAIL      Description
1.0     Nikita Gunjal     12/10/2018  INITIAL DEV      Initial implementattion
***************************************************************************************/

public class OUV_BudgetTriggerHandler {
    
    // Before insert handler logic
    //public static void handleBeforeInsert(List<OUV_Budget__c> ouvBudgetList) {
        
    //    checkBudgetEditPermission(ouvBudgetList);  // not needed to provide edit access on insert of new record
    //}
    
    // Before update handler logic
    public static void handleBeforeUpdate(List<OUV_Budget__c> ouvBudgetList) {
        
        checkBudgetEditPermission(ouvBudgetList);
    }
    
   
    
    /*********************************************************************************
     * Method Name : checkBudgetEditPermission
     * Parameter   : List<OUV_Budget__c>
     * Return type : Static Void
     * Description : validate if user has edit permission to budget record based on 
     *               fleet value and market value by comparing it with public group name
    **********************************************************************************/ 
    
    Public static void checkBudgetEditPermission(List<OUV_Budget__c> ouvBudgetList) {
         
        // Variable definition
        List<ID> ouvLastModifiedIdList = new list<Id>();
        List<String>ouvPublicGroupNameList = new List<String>();         
        String ouvFleet ='';
        MAP<String,String> ouvGroupMap = new MAP<String,String>();
        MAP<string,Set<String>> ouvGroupMemberMap = new MAP<string,Set<String>>();
        List<Id> ouvGroupIdList = new List<Id>();
       
        // get logged in user id
        String ouvLoggedInUserId = UserInfo.getUserId();
        system.debug('ouvLoggedInUserId--'+ouvLoggedInUserId);
        
        // Get the list of groups for the logged in user by querying groupmember data
        for(GroupMember ouvGroupMember : [SELECT GroupId,Id,SystemModstamp,UserOrGroupId FROM GroupMember WHERE UserOrGroupId =: ouvLoggedInUserId]){
            
            Set<String> userIdSet = new Set<String>();
            
            //extract group names for logged in user and add in MAP. One user can be member of multiple groups
            if(ouvGroupMemberMap.get(ouvGroupMember.UserOrGroupId) != null){
                 userIdSet = ouvGroupMemberMap.get(ouvGroupMember.UserOrGroupId);
                 system.debug('userIdSet before--'+userIdSet);
            }
            // add user ids in set as one user can be member of multiple groups. So to avoid multiple entries in collection object we have used set
            userIdSet.add(ouvGroupMember.UserOrGroupId);
            system.debug('userIdSet after--'+userIdSet);
         
            // form a map of group id vs its groupmembers
            ouvGroupMemberMap.put(ouvGroupMember.GroupId,userIdSet);     
            
            // form a list of group id list to get query respective data
            ouvGroupIdList.add(ouvGroupMember.GroupId);
        }
         
        system.debug('ouvGroupMemberMap--'+ouvGroupMemberMap);
        system.debug('ouvGroupIdList--'+ouvGroupIdList);
        
         
        
        // Get group data for all the ids in ouvGroupIdList
        
        for(Group ouvGroup : [Select Id,Name From Group where id IN :ouvGroupIdList]){
            ouvGroupMap.put(ouvGroup.Name, ouvGroup.Id);
        }
        system.debug('ouvGroupMap--'+ouvGroupMap);
        
        
        //Check  each budget record , form a key with combination of 'OUV' + Market +Fleet/ 'OUV'+Market+Finance Team of that record and compare this key with logged in user's group name.
        //If it matches then , user can edit the respective record. If not trigger will throw an error of "Insufficiant access"
        for(OUV_Budget__c ouvBudget : ouvBudgetList){
            
            string ouvFleet1 ='' ;
            string ouvFleet2 ='' ;
            string ouvFleet3 ='' ;
            
            // form a key with OUV+market+Fleet to match it with group name
            if(ouvBudget.OUV_Level_1_Category__c == Label.OUV_PublicRelations)
                ouvFleet1 = 'OUV '+ouvBudget.OUV_Market__c+' '+Label.OUV_PRFleet;
            else if(ouvBudget.OUV_Level_1_Category__c == Label.OUV_Other)
                ouvFleet1 = 'OUV '+ouvBudget.OUV_Market__c+' '+ Label.OUV_OtherFleet;
            else if(ouvBudget.OUV_Level_1_Category__c == Label.OUV_Buybacks)
                ouvFleet1 = 'OUV '+ouvBudget.OUV_Market__c+' '+Label.OUV_FleetBuybackFleet;
            else if(ouvBudget.OUV_Level_1_Category__c == Label.OUV_ExpensedVehicles)
                ouvFleet1 = 'OUV '+ouvBudget.OUV_Market__c+' '+Label.OUV_ExpensedVehiclesFleet;
            else if(ouvBudget.OUV_Level_1_Category__c == Label.OUV_Used)
                ouvFleet1 = 'OUV '+ouvBudget.OUV_Market__c+' '+Label.OUV_RemarketingFleet;
            else if(ouvBudget.OUV_Level_1_Category__c == Label.OUV_EmployeeCars)
                ouvFleet1 = 'OUV '+ouvBudget.OUV_Market__c+' '+Label.OUV_JobRelatedCarsFleet;
            else if(ouvBudget.OUV_Level_1_Category__c == Label.OUV_Marketing){
                ouvFleet1 = 'OUV '+ouvBudget.OUV_Market__c+' '+Label.OUV_MarketingFleet; 
                ouvFleet2 = 'OUV '+ouvBudget.OUV_Market__c+' '+Label.OUV_TrainingFleet; 
            }                   
            else if(ouvBudget.OUV_Level_1_Category__c == Label.OUV_Sales){
                ouvFleet1 = 'OUV '+ouvBudget.OUV_Market__c+' '+Label.OUV_SalesFleet;      // need to calculate this for marketing and sales category as it has two dependent fleets
                ouvFleet2 = 'OUV '+ouvBudget.OUV_Market__c+' '+ Label.OUV_CorporateSalesFleet; 
            }
            ouvFleet3 = 'OUV '+ouvBudget.OUV_Market__c+' '+ Label.OUV_FinanceTeam;    // form a key for finance team as , users in finance team should get edit access to all budgets with same market
            
            system.debug('ouvFleet1--'+ouvFleet1);
            system.debug('ouvFleet2--'+ouvFleet2);
            system.debug('ouvFleet3--'+ouvFleet3);
            
            if(ouvFleet1 != ''  && ouvFleet2 == '' && ouvFleet3 !='' ){
                string ouvGroupId1 = ouvGroupMap.get(ouvFleet1);  // get group id for fleet  group
                system.debug('ouvGroupId1--'+ouvGroupId1);
                
                string ouvGroupId2 = ouvGroupMap.get(ouvFleet3);  // get group id for finance team 
                system.debug('ouvGroupId2--'+ouvGroupId2);
                
                Set<String> userListInPublicGroup1 =  ouvGroupMemberMap.get(ouvGroupId1);
                system.debug('userListInPublicGroup1--'+userListInPublicGroup1);
                
                Set<String> userListInPublicGroup2 =  ouvGroupMemberMap.get(ouvGroupId2);
                system.debug('userListInPublicGroup2--'+userListInPublicGroup2);
                
                if(userListInPublicGroup1==null && userListInPublicGroup2==null){
                    ouvBudget.addError(Label.OUV_Budget_Error_Message);
                }
                
            }
            else if (ouvFleet1 != ''  && ouvFleet2 != ''  && ouvFleet3 != null){
                
                string ouvGroupId1 = ouvGroupMap.get(ouvFleet1);  // get group id for 1st fleet
                string ouvGroupId2 = ouvGroupMap.get(ouvFleet2);  // get group id for 2nd fleet
                string ouvGroupId3 = ouvGroupMap.get(ouvFleet3);  // get group id for finance team
                
                system.debug('ouvGroupId1--'+ouvGroupId1);
                system.debug('ouvGroupId2--'+ouvGroupId2);
                system.debug('ouvGroupId3--'+ouvGroupId3);
                
                Set<String> userListInPublicGroup1 =  ouvGroupMemberMap.get(ouvGroupId1);
                Set<String> userListInPublicGroup2 =  ouvGroupMemberMap.get(ouvGroupId2);
                Set<String> userListInPublicGroup3 =  ouvGroupMemberMap.get(ouvGroupId3);
                
                system.debug('userListInPublicGroup1--'+userListInPublicGroup1);
                system.debug('userListInPublicGroup2--'+userListInPublicGroup2);
                system.debug('userListInPublicGroup3--'+userListInPublicGroup3);
                
                if(userListInPublicGroup1 == null && userListInPublicGroup2 == null && userListInPublicGroup3 == null){
                    ouvBudget.addError(Label.OUV_Budget_Error_Message);
                }
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
}