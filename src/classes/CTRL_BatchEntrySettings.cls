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
                            from Batch__c];   
        batchlist = new list<ExistingBatch>();
        for (Batch__c b : blist){
        	batchlist.add(new ExistingBatch(b));
        }
    }
    
    public void initPage(){
    	
        //load configuration settings
        beconfig = Batch_Data_Entry_Config__c.getOrgDefaults();
        //if we don't have any, configure and create them
        if (beconfig == null){
            beconfig = new Batch_Data_Entry_Config__c();
            
            beconfig.Setupownerid = UserInfo.getOrganizationId();
            //look for the NPSP
            integer npsp_class_count = [select count() from ApexClass where NameSpacePrefix = 'npe01'];
            
            if (npsp_class_count > 0){
                beconfig.Has_NPSP__c = true;
            }
            insert beconfig;
        }
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
    	
    	public ExistingBatch(Batch__c b){
    		batch = b;
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
                if (DescribeHelper.getAllFieldsDescribe(objectName).get(s).isUpdateable() &&
                DescribeHelper.getAllFieldsDescribe(objectName).get(s).isAccessible())
                        fieldlist.add(new SelectOption(s, DescribeHelper.getAllFieldsDescribe(objectName).get(s).getLabel() + ' (' + s + ')') );
            
                if (!DescribeHelper.getAllFieldsDescribe(objectName).get(s).isNillable() && 
                    !DescribeHelper.getAllFieldsDescribe(objectName).get(s).isDefaultedOnCreate())
                        entrylist.add(s);                
            }
            
            return fieldlist;
        }
        public list<SelectOption> availablelistfields;    
        public list<SelectOption> getavailableListFields(){
            
            list<SelectOption> fieldlist = new list<SelectOption>();
            
            if (savelist == null)
                savelist = new list<string>();
            
            for (string s : DescribeHelper.getAllFieldsDescribe(objectName).keySet()){
                if (DescribeHelper.getAllFieldsDescribe(objectName).get(s).isUpdateable() &&
                DescribeHelper.getAllFieldsDescribe(objectName).get(s).isAccessible())
                    fieldlist.add(new SelectOption(s, DescribeHelper.getAllFieldsDescribe(objectName).get(s).getLabel() + ' (' + s + ')') );
            
            }        
            return fieldlist;
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
    			objectlist.add(new SelectOption('', '- None -'));
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
    
    public static testMethod void testController(){
    	
    	
    }
    
    
    
}