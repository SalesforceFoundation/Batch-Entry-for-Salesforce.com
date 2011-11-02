/*
Copyright (c) 2011, salesforce.com foundation, Inc.
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, 
are permitted provided that the following conditions are met:

    * Redistributions of source code must retain the above copyright notice, 
    this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright notice, 
    this list of conditions and the following disclaimer in the documentation 
    and/or other materials provided with the distribution.
    * Neither the name of the salesforce.com foundation. nor the names of its contributors 
    may be used to endorse or promote products derived from this software 
    without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. 
IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, 
INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF 
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE 
OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED 
OF THE POSSIBILITY OF SUCH DAMAGE.

*/
/**
* @author Salesforce.com Foundation
* @date 10/2011
* @description controller for the batch entry settings page.
*/

public with sharing class CTRL_BatchEntrySettings {

    public list<BatchEntrySetting> bulkEntrySettings {get; private set;}
    public BatchEntrySetting activeSetting {get; set;}
    public boolean settingLoaded {get { return (activeSetting != null) ? true : false;}}
    
    public set<string> existingSettingsName = new set<string>();
    
    public Batch_Data_Entry_Config__c beconfig {get; set;}
    public boolean editingConfig {get; set;}

    public string activetab {get; set;}
    
    public string deleteID{get; set;}
    
    public list<ExistingBatch> batchlist{get; set;}
    public ExistingBatch selectedbatch {get; set;} 
    
    public boolean npspIsInstalled{get; set;}
    
    public id selectedbatchid{get; set;}
    //constructor
    public CTRL_BatchEntrySettings(){
    	
    	editingConfig = false;
    	activetab = 'fieldmapping';
    	
    	//load existing settings into the list
    	list<BulkDataEntry__c> existingSettings = BulkDataEntry__c.getAll().values();
     	bulkEntrySettings = new list<BatchEntrySetting>();
     	if (existingSettings != null){     		
     		for (BulkDataEntry__c bde : existingSettings){
                bulkEntrySettings.add(new BatchEntrySetting(bde, this));    
                existingSettingsName.add(bde.Name);                 			
     		}     		
     	}
     	
     	if (ApexPages.currentPage().getParameters().get('setting') != null){
            for (BatchEntrySetting bes : bulkEntrySettings){
                if (bes.mysetting.id == ApexPages.currentPage().getParameters().get('setting')){
                    activeSetting = bes;                	
                }           	
            }           
        }        
        
        list<Batch__c> blist = [select SystemModstamp, OwnerId, Object_Name__c, 
                            Number_of_Items__c, Name, LastModifiedDate, 
                            LastModifiedById, IsDeleted, Id, Description__c,
                            CreatedDate, CreatedById, Batch_Status__c 
                            from Batch__c order by LastModifiedDate desc];   
        batchlist = new list<ExistingBatch>();
        for (Batch__c b : blist){
        	batchlist.add(new ExistingBatch(b, this));
        }
    }
    
    public void initPage(){
    	
        //load configuration settings
        beconfig = Batch_Data_Entry_Config__c.getOrgDefaults();
        
        //look for the NPSP
        integer npsp_class_count = [select count() from ApexClass where NameSpacePrefix = 'npe01'];
        if (npsp_class_count > 0){
        	npspIsInstalled = true;
        }
        else{
        	npspIsInstalled = false;
        }
        
        //if we don't have any, configure and create them
        if (beconfig == null){
            beconfig = new Batch_Data_Entry_Config__c();
            
            beconfig.Setupownerid = UserInfo.getOrganizationId();
            
            if (npsp_class_count > 0){
                beconfig.Has_NPSP__c = true;
            }
            insert beconfig;
        }        
    }
    
    public pageReference deleteBatch(){
            integer i = 0;
            integer deletenum;
            for (ExistingBatch be : batchlist){
            	system.assert(selectedbatchid != null);
            	if (be.batch.id == selectedbatchid){
            		delete be.batch;
            		deletenum = i;            		
            	}
            	i++;
            }
            batchlist.remove(deletenum);
                    
            activeTab='batchdeletetab';
            return null;
    } 
    
    
    public void deleteItem(BatchEntrySetting bes) {
    	activetab='fieldmapping';
        delete bes.mysetting;
        for (integer i = 0; i < bulkEntrySettings.size(); i++) {
            if (bulkEntrySettings[i].mysetting.Name == bes.mysetting.Name) { 
                bulkEntrySettings.remove(i);
                break;
            }
        }
    }
    
    public pageReference createNew(){
    	activetab='fieldmapping';
    	
    	BatchEntrySetting bes = new BatchEntrySetting(new BulkDataEntry__c(), this);
    	activeSetting = bes;
    	return null;
    }
    
    public pageReference saveSetting(){
    	activetab='fieldmapping';
    	
    	if (activeSetting != null){
            boolean isSuccess;
            
            isSuccess = activeSetting.upsertBDESetting();                		
    		
            if (isSuccess){
            	ApexPages.PageReference pr = ApexPages.currentPage();       
            	pr.getParameters().clear();
            	existingSettingsName.clear();
            	activeSetting = null;      
                return pr.setRedirect(true);
            }
            else{            	
            	showMsg('Upsert Failed', ApexPages.Severity.ERROR);
                return null; 
            }
    	}
    	else{    		
    		showMsg('No Object Loaded', ApexPages.Severity.ERROR);
    		return null;
    	}
    }
    
    public pageReference cancel(){    	
    	ApexPages.PageReference pr = ApexPages.currentPage();              
        return pr.setRedirect(true);
    }
    
    public pageReference editAdvancedSettings(){
    	activetab = 'advancedconfig';
    	editingConfig = true;    	
    	return null;
    }
    
    public pageReference cancelAdvancedSettings(){
    	activetab = 'advancedconfig';
    	editingConfig = false;
    	//reload the original settings
    	beconfig = Batch_Data_Entry_Config__c.getOrgDefaults();
    	
    	return null;
    }
    
    public pageReference saveAdvancedSettings(){
    	activetab = 'advancedconfig';
    	try{
    		update beconfig;
    		editingConfig = false; 
    	}
    	catch(Exception e){    		
    		showMsg(e.getMessage(), ApexPages.Severity.ERROR);
    	}
    	
    	return null;    	
    }
    
    
    private void showMsg(String arg, ApexPages.Severity severity){
        ApexPages.Message myMsg = new ApexPages.Message(severity,arg);
        ApexPages.addMessage(myMsg);
    }    
    
    public class ExistingBatch{
    	public Batch__c batch {get; set;}
    	public CTRL_BatchEntrySettings mydad{get; set;}
    	
    	public ExistingBatch(Batch__c b, CTRL_BatchEntrySettings bes){
    		batch = b;
    		mydad = bes;
    	}
    }
    
    //handles settings in the list, and working with settings as the object
    public class BatchEntrySetting{
        
        public list<SelectOption> objectlist {get; set;}
        public string objectname {get; set;}            
    
        //selected fields              
        public list<string> saveList {get;set;}
        public list<string> entryList {get;set;}
    
        public integer SettingsListSize{get {return objectlist.size();}}
    
        public list<SelectOption> availableDEFields;            	
    	public list<SelectOption> getavailableDEFields(){
            list<SelectOption> fieldlist = new list<SelectOption>();
            if (entrylist == null)
                entrylist = new list<string>();
            
            for (string s : DescribeHelper.getAllFieldsDescribe(objectName).keySet()){
                if ((DescribeHelper.getAllFieldsDescribe(objectName).get(s).isUpdateable() &&
                DescribeHelper.getAllFieldsDescribe(objectName).get(s).isAccessible())   || (DescribeHelper.getAllFieldsDescribe(objectName).get(s).isCreateable()))
                        fieldlist.add(new SelectOption(s, DescribeHelper.getAllFieldsDescribe(objectName).get(s).getLabel() + ' (' + s + ')') );
            
                if (!DescribeHelper.getAllFieldsDescribe(objectName).get(s).isNillable() && 
                    !DescribeHelper.getAllFieldsDescribe(objectName).get(s).isDefaultedOnCreate())
                        entrylist.add(s);                
            }
            
            return mydad.sortOptionList(fieldlist);
        }
        public list<SelectOption> availablelistfields;    
        public list<SelectOption> getavailableListFields(){
            
            list<SelectOption> fieldlist = new list<SelectOption>();
            
            if (savelist == null)
                savelist = new list<string>();
            
            for (string s : DescribeHelper.getAllFieldsDescribe(objectName).keySet()){
                fieldlist.add(new SelectOption(s, DescribeHelper.getAllFieldsDescribe(objectName).get(s).getLabel() + ' (' + s + ')') );
            }        
            
            return mydad.sortOptionList(fieldlist);
        }
    	
    	
    	public BulkDataEntry__c mysetting{get; set;}
    	CTRL_BatchEntrySettings mydad;
    	
    	public BatchEntrySetting(BulkDataEntry__c bdeSetting, CTRL_BatchEntrySettings parent){
    		mysetting = bdesetting;
    		mydad = parent; 
    		objectname = bdesetting.Name;
    		if (entrylist == null) entrylist = new list<string>();
    		if (savelist == null) savelist = new list<string>();
    		
    		//setup the object list when we load a setting
    		objectlist= new list<SelectOption>();
    		//if we're loading an existing setting, add the object
    		//name to the list, and lock the list
    		if (objectname != null && objectname != ''){
    			objectlist.add(new SelectOption(bdesetting.Name, bdesetting.Name));    		
    			
    			
    			if (bdesetting.Object_Entry_Field_Set__c != null){
    		      	//and we need to add the existing selection to the savelist and entrylist
                    for (string s : bdesetting.Object_Entry_Field_Set__c.split(',')){
    				    system.debug('Adding: ' + s);
    				    entrylist.add(s);
    			    }
    			}
    			
    			if (bdesetting.Object_List_Field_Set__c != null){
    			    for (string s : bdesetting.Object_List_Field_Set__c.split(',')){
                        system.debug('Adding: ' + s);
                        savelist.add(s);
                    }
    			}
                			
            }
    		
    		//else, its a new setting
    		//and we need to load the list of possible objects
    		else{
    			
    			map<string, Schema.Sobjecttype> objectmap = Schema.getGlobalDescribe();
    			for (string s : objectmap.keySet()){
    				Schema.DescribeSObjectResult dsr = objectmap.get(s).getDescribe();
    				//if we don't have a setting for the object, list it as an option
    				//if its also creatable/accessible/updateable
    				if (!mydad.existingSettingsName.contains(s) &&
    				dsr.isUpdateable() && dsr.isCreateable() && dsr.isAccessible()){
    				    objectlist.add(new SelectOption(s, objectmap.get(s).getDescribe().getLabel()));
    				}
    			}     			
                
                //sort our object list before exiting constructor
                objectlist = mydad.sortOptionList(objectlist);    		      
                objectlist.add(0, new SelectOption('', '- None -'));
    		}
    		
    		
    	}
    	
    	public pageReference editItem(){  
    		mydad.activetab='fieldmapping';  		
    		mydad.activeSetting = this;
    		return null;
    	}
    	
    	public pageReference deleteItem(){    		
    		mydad.activetab='fieldmapping';
    		mydad.existingSettingsName.remove(this.objectname);
    		mydad.deleteItem(this);
    		return null;
    	}
    	
    	public boolean upsertBDESetting(){
    		mydad.activetab='fieldmapping';
    		boolean isSuccess;
    		string dataentryfields = '';
    		string savelistfields = '';
    		
    		//create a new setting if needed and provide the name
    		if (mysetting == null){
                mysetting = new BulkDataEntry__c();
    		}                
            
            mysetting.Name = objectname; 
            mysetting.Save_Batch__c = true;
                		  
    		integer counter = 0;
    		//save other settings
    		for (string s : entrylist){
    			dataentryfields += s;
    			counter++;
    			if (counter < entrylist.size()){
    				dataentryfields += ',';
    			}    			
    		}
    		
    		counter = 0;
    		for (string s : savelist){
    			savelistfields += s;
    			counter ++;
    			if (counter < savelist.size()){
    				savelistfields += ',';
    			}    			
    		}
    		
    		mysetting.Object_Entry_Field_Set__c = dataentryfields;
    		mysetting.Object_List_Field_Set__c = savelistfields;
    		
    		try{
    			upsert mysetting;
    			isSuccess = true; 
    		}
    		catch (Exception e){
    			isSuccess = false;    			
    		}
    		return isSuccess;
    	}
    }	
    
    
    //http://improveit360.blogspot.com/2010/09/implementing-quicksort-to-sort-list-of.html
    public list<SelectOption> sortOptionList(list<SelectOption> ListToSort)
    {
        if(ListToSort == null || ListToSort.size() <= 1)
            return ListToSort;
            
        List<SelectOption> Less = new List<SelectOption>();
        List<SelectOption> Greater = new List<SelectOption>();
        integer pivot = ListToSort.size() / 2;
          
        // save the pivot and remove it from the list
        SelectOption pivotValue = ListToSort[pivot];
        ListToSort.remove(pivot);
        
        for(SelectOption x : ListToSort)
        {
            if(x.getLabel() <= pivotValue.getLabel())
                Less.add(x);
            else if(x.getLabel() > pivotValue.getLabel()) Greater.add(x);   
        }
        List<SelectOption> returnList = new List<SelectOption> ();
        returnList.addAll(SortOptionList(Less));
        returnList.add(pivotValue);
        returnList.addAll(SortOptionList(Greater));
        return returnList; 
    }
    
    public static testMethod void testController(){
        
        delete [select id from BulkDataEntry__c];
        
        BulkDataEntry__c bde = new BulkDataEntry__c(Name = 'opportunity', Save_Batch__c = true,
        Object_Entry_Field_Set__c = 'name,accountid,amount,stagename,closedate',
        Object_List_Field_Set__c = 'name,accountid,amount');
        insert bde;     
        
        //insert a batch
        Batch__c batch_to_delete = new Batch__c(Name = 'Delete me', Object_name__c = 'opportunity');
        insert batch_to_delete;
        
        //delete existing be config records
        delete [select id from Batch_Data_Entry_Config__c];
            
        Test.setCurrentPage(Page.BatchEntrySettings); 
        ApexPages.currentPage().getParameters().put('setting', bde.id);
        CTRL_BatchEntrySettings ctrl = new CTRL_BatchEntrySettings(); 
        ctrl.initPage();
        
        //we have loaded the existing contact setting
        system.assert(ctrl.batchlist.size() > 0);
        
        //test deletion of a batch
        ctrl.selectedbatchid = batch_to_delete.id;
        ctrl.deleteBatch();
        system.assertEquals(0, [select count() from Batch__c where id = :batch_to_delete.id]); 
        
        //run batchentrysetting methods
        BatchEntrySetting bes = ctrl.bulkEntrySettings[0];
        ctrl.activeSetting = bes;
        
        //test subclass props and methods
        list<SelectOption> delist = ctrl.activeSetting.getavailableDEFields();
        list<SelectOption> lelist = ctrl.activeSetting.getavailableListFields();
        system.assertNotEquals(delist.size(), 0);
        system.assertNotEquals(lelist.size(), 0);
        ctrl.activeSetting.entryList = null;
        ctrl.activeSetting.savelist = null;
        delist = ctrl.activesetting.getavailabledefields();
        lelist = ctrl.activesetting.getavailablelistfields();
        
        ctrl.activeSetting.editItem();
        system.assertEquals(ctrl.activeSetting, bes);
        system.assertNotEquals(ctrl.activeSetting.saveList, null);
        system.assertNotEquals(ctrl.activeSetting.entryList, null);
        integer listsize = ctrl.activeSetting.SettingsListSize;
        BulkDataEntry__c testbde = ctrl.activeSetting.mysetting;
        system.assertEquals(testbde.id, bde.id);                
        system.assertEquals(ctrl, ctrl.activeSetting.mydad);
        
        //create a new setting through the page
        ctrl.createNew();
        //set some values
        ctrl.activeSetting.objectname = 'contact';
        ctrl.activeSetting.saveList = new list<string>{'LastName', 'Birthdate', 'FirstName'};
        ctrl.activeSetting.entryList = new list<string>{'LastName', 'Birthdate', 'FirstName'};
        ctrl.saveSetting();
        system.assertNotEquals(0, [select count() from BulkDataEntry__c where Name = 'contact']);
        ctrl.activeSetting = new BatchEntrySetting([select id, Name, Object_Entry_Field_Set__c, Object_List_Field_Set__c from BulkDataEntry__c where Name = 'contact'], ctrl);
        ctrl.activeSetting.deleteItem();
        system.assertEquals(0, [select count() from BulkDataEntry__c where Name = 'contact']);
        
        //exercise be config settings
        ctrl.cancel();
        ctrl.cancelAdvancedSettings();
        ctrl.editAdvancedSettings();
        ctrl.saveAdvancedSettings();
        
        //delete our existing setting 
        ctrl.activesetting = new BatchEntrySetting(bde, ctrl);
        ctrl.deleteItem(ctrl.activeSetting);
        system.assertEquals(0, [select count() from BulkDataEntry__c where id = :bde.id]);
    
        //test some error scenarios
        ctrl.activesetting.objectname = null;
        ctrl.saveSetting();
        
        ctrl.activesetting.mysetting = null;
        ctrl.activesetting.upsertBDESetting();
        
        ctrl.activesetting = null;
        ctrl.saveSetting();
        
        ctrl.beconfig = null;
        ctrl.saveAdvancedSettings();        
    }
    
    
    
}