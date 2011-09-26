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

/*
 * controller for the batch entry page.
 * authors: Team Kick Ass; Veronica Waters, Evan Callahan, Derek Dsouza, Mike Fullmore
 * date 04/27/2011
*/

public with sharing class CTRL_BatchEntry {

        public batch__c batch { get; set; }
        public boolean displayBatchSection { get; private set; }   // could be transient?
        public boolean displayRecInfoSection { get; private set; }     // could be transient?
        public boolean displaySettingsSection { get; private set; }     // could be transient?
        
        public List<SelectOption> objectSettingsList { get; private set; }

        public BatchItem currentItem { get; set; }   // could be transient - already getting it on edit, otherwise should be clear (what about errors?)
        public list<BatchItem> itemList { get; private set; }	// could be transient - would need list of ids instead

		// could get all this every time, but not a lot of viewstate
        public string objname { get; set; }
        public string batchLookupField { get; private set; }
        public string pageSubtitle { get; private set; }
        public list<EntryField> entryFieldList { get; private set; }
        public list<string> listFieldList { get; private set; }

        public integer itemCount { get { return (itemList != null) ? itemList.size() : 0; } }
                
        public CTRL_BatchEntry(ApexPages.StandardController stdController) {

                if (stdController.getId() == null)
                	batch = new Batch__c();
                else
                	batch = [select id, name, object_name__c, batch_status__c, Number_of_Items__c from batch__c where id =: stdController.getId()];

                objname = (batch.id != null) ? 
                        batch.object_name__c :
                        ApexPages.currentPage().getParameters().get('obj');

                BulkDataEntry bde = new BulkDataEntry(objname);                
                
                if (!bde.getStatusMessage().contains(bde.getFailureMessage())){        		
	            		objname = bde.getObjectName();
	                	if(objname!=null) {
	                        batchLookupField = bde.getBatchLookupFieldname();
	                        displayBatchSection = bde.getSaveBatch();                       
	                        displayRecInfoSection = true;
	                        
	                        String pluralName = DescribeHelper.getObjectDescribe(objname).getLabelPlural();
	                        pageSubtitle = pluralName;
	                                                
	                        entryFieldList = new list<EntryField>();
	                        for (string fn : bde.getEntryFieldList())
	                                entryFieldList.add(new EntryField(objname, fn));
	                        listFieldList = bde.getListFieldList();                   
	                                        
	                        itemList = new list<BatchItem>();
	                
	                        if (displayBatchSection) {
	                                // create the batch if it is new
	                                if (batch.id == null) {                                        
	                                        batch.name = pluralName + ' ' + system.today().format();
	                                        batch.object_name__c = objName;
	                                        // we will insert this in the load event
	                                } else {
	                                        string q = bde.getQueryString();
	                                        q += ' where ' + batchLookupField + ' = \'' + batch.id + '\'';
	                                        for (sObject existing : database.query(q)) {
	                                                itemList.add(new BatchItem(this, existing));
	                                        }       
	                                }
	                        }       
	        
	                        currentItem = new BatchItem(this);
                        } else {
                        	objectSettingsList = new List<SelectOption>();
                        	for(BulkDataEntry__c b : bde.getBulkCustomSettingsList()) {
                        		objectSettingsList.add(new SelectOption(b.Name, DescribeHelper.getObjectDescribe(b.Name).getLabel()));
                        	}
                        	pageSubtitle = 'Batch Data Entry Home';
                        	displaySettingsSection = true;
                        	displayBatchSection = false;
                        	displayRecInfoSection = false;                        	
                        }                       
                } else {             
                        ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.Error, bde.getStatusMessage()));
                        displaySettingsSection = false;
                        displayBatchSection = false;
                        displayRecInfoSection = false;
                }                
        }

      	public class EntryField {
        	    public string fieldName { get; private set; }
            	public string fieldLabel { get; private set; }
                        
            	public entryField(string obj, string fld) {
                	fieldName = fld;
                    fieldLabel = DescribeHelper.getFieldLabel(obj, fld);
                    if(fieldName.toUpperCase().endsWith('ID') && fieldLabel.toUpperCase().endsWith('ID'))     
                    	fieldLabel=fieldLabel.substring(0, fieldLabel.length()-2);               
                }
        }
                
        public class BatchItem {
                
                CTRL_BatchEntry mydad;
                public integer itemNum { get; private set; }
                public sobject sobj { get; set; }
                
                public BatchItem(CTRL_BatchEntry parentClass) {
                        mydad = parentClass;       
                        sobj = DescribeHelper.getPrototypeObject(mydad.objname); //this line needs to be outside the check for displayBatchSection or we get an error on page load for any object where !displayBatchSection          
                        if (mydad.displayBatchSection) {
                            sobj.put(mydad.batchLookupField, parentClass.batch.id);
                        }
                }
                
                public BatchItem(CTRL_BatchEntry parentClass, sobject existingItem) {
                        mydad = parentClass;
                        sobj = existingItem;
                }
                
                public pageReference editItem() {
                        // load this item into data entry section
                        myDad.currentItem = this;
                        return null;
                }
                
                public pageReference deleteItem() {
                        // delete this item from the list
                        myDad.deleteItem(sobj);
                        return null;
                }
        }
        
        public pageReference saveBatch() {
				// if we are using batch, save the batch                
                if (displayBatchSection && itemList!=null && !itemList.isEmpty()) {
                	batch.number_of_items__c = itemList.size();

                	if (batch.id == null)
                        insert batch;
                    else
                    	update batch;
                }
                return null;
        }
        
        public pageReference save() {
        		if (currentItem.sobj.id != null) {
                        update currentItem.sobj;
                } else {         
                		if (itemList.isEmpty()) {
                				itemList.add(currentItem);
                        		saveBatch();
                        		currentItem.sobj.put(batchLookupField, batch.Id);
                        		insert currentItem.sobj;                                
                        }
                        else {
                        		insert currentItem.sobj;
                                itemList.add(0, currentItem);
                        }                        
                }
                currentItem = new BatchItem(this);
                return null;    
        }

        public pageReference clear() {
                currentItem = new BatchItem(this);
                return null;
        }
        
        public void deleteItem(sobject sobj) {
                delete sobj;
                for (integer i = 0; i < itemList.size(); i++) {
                        if (itemList[i].sobj.id == sobj.id) { 
                                itemList.remove(i);
                                break;
                        }
                }
        }
        
        public pageReference openBatchEnterPage() {
        	PageReference pageRef = Page.BatchEntry;
        	pageRef.getParameters().put('obj', objName);
        	pageRef.setRedirect(true);
        	return pageRef;        	
        }
        
        public pageReference editBatchSetting() {
        	List<BulkDataEntry__c> setting = [Select Id from BulkDataEntry__c where Name=:objName];        	
        	PageReference pageRef = new PageReference('/' + setting[0].Id);
        	return pageRef;   	
        }
        
        public pageReference createBatchSetting() {
        	String id = DescribeHelper.getObjectDescribe(String.valueOf(BulkDataEntry__c.sObjectType)).getKeyPrefix();        	
        	PageReference pageRef = new PageReference('/setup/ui/editCustomSettingsData.apexp');
        	pageRef.getParameters().put('id', id);
        	pageRef.getParameters().put('retURL', Page.BatchEntry.getUrl());
        	return pageRef;   	
        }
        
        /* Tests */
        
	    static testMethod void testBatchWithSave() {
			// create settings object
			
			ApexPages.StandardController sc = new ApexPages.standardController( new Batch__c() );
			Test.setCurrentPage(Page.BatchEntry); 
			ApexPages.currentPage().getParameters().put('obj', 'Contact');
			CTRL_BatchEntry ext = new CTRL_BatchEntry(sc); 
	
			// set some fields
			ext.currentItem.sobj.put('LastName', 'Test');
			ext.save();		
	
			// do it again with the saved record
			sc = new ApexPages.standardController( ext.batch );
			Test.setCurrentPage(Page.BatchEntry); 
			ApexPages.currentPage().getParameters().put('obj', 'Contact');
			ext = new CTRL_BatchEntry(sc); 
		}
	
		static testMethod void testBatchNotSaved() {
			
		}        
}