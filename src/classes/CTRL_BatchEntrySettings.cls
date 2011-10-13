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
       
    
    public list<string> saveList {get;set;}
    public list<string> entryList {get;set;}
    public list<SelectOption> availableDEFields;
    public list<SelectOption> availablelistfields;
    
    public list<SelectOption> getavailableDEFields(){
    	list<SelectOption> fieldlist = new list<SelectOption>();
    	
    	return fieldlist;
    }
    
    public list<SelectOption> getavailableListFields(){
    	list<SelectOption> fieldlist = new list<SelectOption>();
    	
    	return fieldlist;
    }
            
    //constructor
    public CTRL_BatchEntrySettings(){
    	
    	//load existing settings into the list
    	list<BulkDataEntry__c> existingSettings = BulkDataEntry__c.getAll().values();
     	bulkEntrySettings = new list<BatchEntrySetting>();
     	if (existingSettings != null){     		
     		for (BulkDataEntry__c bde : existingSettings){
                bulkEntrySettings.add(new BatchEntrySetting(bde, this));     			
     		}     		
     	}
    }
    
    
    
    
    
    
    public void deleteItem(BatchEntrySetting bes) {
        delete bes.mysetting;
        for (integer i = 0; i < bulkEntrySettings.size(); i++) {
            if (bulkEntrySettings[i].mysetting.Name == bes.mysetting.Name) { 
                bulkEntrySettings.remove(i);
                break;
            }
        }
    }
    
    
    //handles settings in the list, and working with settings as the object
    public class BatchEntrySetting{
    	
    	public BulkDataEntry__c mysetting{get; set;}
    	CTRL_BatchEntrySettings mydad;
    	
    	public BatchEntrySetting(BulkDataEntry__c bdeSetting, CTRL_BatchEntrySettings parent){
    		mysetting = bdesetting;
    		mydad = parent;
    	}
    	
    	public pageReference editItem(){    		
    		mydad.activeSetting = this;
    		return null;
    	}
    	
    	public pageReference deleteItem(){    		
    		mydad.deleteItem(this);
    		return null;
    	}
    }
}