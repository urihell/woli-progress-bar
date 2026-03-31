@IsTest
private class WOLIProgressHandlerTest {

    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        WorkOrder wo = new WorkOrder(
            AccountId = acc.Id,
            Subject = 'Test WO'
        );
        insert wo;

        List<ServiceAppointment> sas = new List<ServiceAppointment>();
        for (Integer i = 0; i < 2; i++) {
            sas.add(new ServiceAppointment(
                ParentRecordId = wo.Id,
                EarliestStartDate = DateTime.now(),
                DueDate = DateTime.now().addDays(1),
                Subject = 'Test SA ' + i
            ));
        }
        insert sas;
    }

    private static WorkOrder getWorkOrder() {
        return [SELECT Id FROM WorkOrder LIMIT 1];
    }

    private static List<ServiceAppointment> getServiceAppointments() {
        return [SELECT Id, WOLI_Progress__c FROM ServiceAppointment ORDER BY Subject];
    }

    @IsTest
    static void testInsertWOLIs_BothFormat() {
        WorkOrder wo = getWorkOrder();

        List<WorkOrderLineItem> wolis = new List<WorkOrderLineItem>();
        wolis.add(new WorkOrderLineItem(WorkOrderId = wo.Id, Status = 'Completed'));
        wolis.add(new WorkOrderLineItem(WorkOrderId = wo.Id, Status = 'New'));
        wolis.add(new WorkOrderLineItem(WorkOrderId = wo.Id, Status = 'New'));

        Test.startTest();
        insert wolis;
        Test.stopTest();

        List<ServiceAppointment> sas = getServiceAppointments();
        for (ServiceAppointment sa : sas) {
            System.assertNotEquals(null, sa.WOLI_Progress__c, 'Progress should be set');
            System.assert(sa.WOLI_Progress__c.contains('33%'), 'Should show 33% — got: ' + sa.WOLI_Progress__c);
            System.assert(sa.WOLI_Progress__c.contains('['), 'Should contain block bar — got: ' + sa.WOLI_Progress__c);
        }
    }

    @IsTest
    static void testUpdateWOLIStatus() {
        WorkOrder wo = getWorkOrder();

        List<WorkOrderLineItem> wolis = new List<WorkOrderLineItem>();
        wolis.add(new WorkOrderLineItem(WorkOrderId = wo.Id, Status = 'New'));
        wolis.add(new WorkOrderLineItem(WorkOrderId = wo.Id, Status = 'New'));
        insert wolis;

        Test.startTest();
        wolis[0].Status = 'Completed';
        update wolis;
        Test.stopTest();

        List<ServiceAppointment> sas = getServiceAppointments();
        for (ServiceAppointment sa : sas) {
            System.assert(sa.WOLI_Progress__c.contains('50%'), 'Should show 50% — got: ' + sa.WOLI_Progress__c);
        }
    }

    @IsTest
    static void testAllCompleted() {
        WorkOrder wo = getWorkOrder();

        List<WorkOrderLineItem> wolis = new List<WorkOrderLineItem>();
        wolis.add(new WorkOrderLineItem(WorkOrderId = wo.Id, Status = 'Completed'));
        wolis.add(new WorkOrderLineItem(WorkOrderId = wo.Id, Status = 'Completed'));

        Test.startTest();
        insert wolis;
        Test.stopTest();

        List<ServiceAppointment> sas = getServiceAppointments();
        for (ServiceAppointment sa : sas) {
            System.assert(sa.WOLI_Progress__c.contains('100%'), 'Should show 100% — got: ' + sa.WOLI_Progress__c);
        }
    }

    @IsTest
    static void testDeleteWOLI() {
        WorkOrder wo = getWorkOrder();

        List<WorkOrderLineItem> wolis = new List<WorkOrderLineItem>();
        wolis.add(new WorkOrderLineItem(WorkOrderId = wo.Id, Status = 'Completed'));
        wolis.add(new WorkOrderLineItem(WorkOrderId = wo.Id, Status = 'New'));
        insert wolis;

        Test.startTest();
        delete wolis[1];
        Test.stopTest();

        List<ServiceAppointment> sas = getServiceAppointments();
        for (ServiceAppointment sa : sas) {
            System.assert(sa.WOLI_Progress__c.contains('100%'), 'Should show 100% after delete — got: ' + sa.WOLI_Progress__c);
        }
    }

    @IsTest
    static void testDeleteAllWOLIs() {
        WorkOrder wo = getWorkOrder();

        WorkOrderLineItem woli = new WorkOrderLineItem(WorkOrderId = wo.Id, Status = 'New');
        insert woli;

        Test.startTest();
        delete woli;
        Test.stopTest();

        List<ServiceAppointment> sas = getServiceAppointments();
        for (ServiceAppointment sa : sas) {
            System.assert(sa.WOLI_Progress__c.contains('0%'), 'Should show 0% when no WOLIs — got: ' + sa.WOLI_Progress__c);
        }
    }

    @IsTest
    static void testUndeleteWOLI() {
        WorkOrder wo = getWorkOrder();

        List<WorkOrderLineItem> wolis = new List<WorkOrderLineItem>();
        wolis.add(new WorkOrderLineItem(WorkOrderId = wo.Id, Status = 'Completed'));
        wolis.add(new WorkOrderLineItem(WorkOrderId = wo.Id, Status = 'New'));
        insert wolis;

        delete wolis[1];

        Test.startTest();
        undelete wolis[1];
        Test.stopTest();

        List<ServiceAppointment> sas = getServiceAppointments();
        for (ServiceAppointment sa : sas) {
            System.assert(sa.WOLI_Progress__c.contains('50%'), 'Should show 50% after undelete — got: ' + sa.WOLI_Progress__c);
        }
    }

    @IsTest
    static void testBulkWOLIs() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        List<WorkOrder> wos = new List<WorkOrder>();
        for (Integer i = 0; i < 5; i++) {
            wos.add(new WorkOrder(AccountId = acc.Id, Subject = 'Bulk WO ' + i));
        }
        insert wos;

        List<ServiceAppointment> sas = new List<ServiceAppointment>();
        for (WorkOrder wo : wos) {
            sas.add(new ServiceAppointment(
                ParentRecordId = wo.Id,
                EarliestStartDate = DateTime.now(),
                DueDate = DateTime.now().addDays(1),
                Subject = 'Bulk SA ' + wo.Subject
            ));
        }
        insert sas;

        List<WorkOrderLineItem> wolis = new List<WorkOrderLineItem>();
        for (WorkOrder wo : wos) {
            for (Integer i = 0; i < 40; i++) {
                wolis.add(new WorkOrderLineItem(
                    WorkOrderId = wo.Id,
                    Status = (Math.mod(i, 2) == 0) ? 'Completed' : 'New'
                ));
            }
        }

        Test.startTest();
        insert wolis;
        Test.stopTest();

        List<ServiceAppointment> updatedSAs = [
            SELECT Id, WOLI_Progress__c
            FROM ServiceAppointment
            WHERE ParentRecordId IN :wos
        ];
        for (ServiceAppointment sa : updatedSAs) {
            System.assert(sa.WOLI_Progress__c.contains('50%'), 'Bulk: should show 50% — got: ' + sa.WOLI_Progress__c);
        }
    }

    @IsTest
    static void testMultipleSAsPerWorkOrder() {
        WorkOrder wo = getWorkOrder();

        WorkOrderLineItem woli = new WorkOrderLineItem(WorkOrderId = wo.Id, Status = 'Completed');

        Test.startTest();
        insert woli;
        Test.stopTest();

        List<ServiceAppointment> sas = getServiceAppointments();
        System.assertEquals(2, sas.size(), 'Should have 2 SAs');
        for (ServiceAppointment sa : sas) {
            System.assert(sa.WOLI_Progress__c.contains('100%'), 'Both SAs should show 100% — got: ' + sa.WOLI_Progress__c);
        }
    }
}
