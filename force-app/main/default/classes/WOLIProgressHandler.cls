public with sharing class WOLIProgressHandler {

    private static final String FILLED_BLOCK = '\u25A0'; // ■
    private static final String EMPTY_BLOCK  = '\u25A1'; // □

    public static void handleProgress(
        List<WorkOrderLineItem> newItems,
        List<WorkOrderLineItem> oldItems
    ) {
        Set<Id> workOrderIds = new Set<Id>();
        if (newItems != null) {
            for (WorkOrderLineItem woli : newItems) {
                workOrderIds.add(woli.WorkOrderId);
            }
        }
        if (oldItems != null) {
            for (WorkOrderLineItem woli : oldItems) {
                workOrderIds.add(woli.WorkOrderId);
            }
        }
        workOrderIds.remove(null);
        if (workOrderIds.isEmpty()) {
            return;
        }

        WOLI_Progress_Setting__mdt settings = WOLI_Progress_Setting__mdt.getInstance('Default');
        String displayFormat = (settings != null && settings.Display_Format__c != null)
            ? settings.Display_Format__c : 'Both';
        Integer blockCount = (settings != null && settings.Block_Count__c != null)
            ? (Integer) settings.Block_Count__c : 10;
        Set<String> completedStatuses = parseStatuses(
            (settings != null && settings.Completed_Status__c != null)
                ? settings.Completed_Status__c : 'Completed'
        );
        Boolean updateGanttLabel = (settings != null && settings.Update_Gantt_Label__c != null)
            ? settings.Update_Gantt_Label__c : false;

        // Check if FSL__GanttLabel__c exists (FSL may not be installed)
        Boolean ganttFieldExists = updateGanttLabel &&
            Schema.SObjectType.ServiceAppointment.fields.getMap().containsKey('FSL__GanttLabel__c');

        Map<Id, Integer> totalByWO = new Map<Id, Integer>();
        Map<Id, Integer> completedByWO = new Map<Id, Integer>();

        for (Id woId : workOrderIds) {
            totalByWO.put(woId, 0);
            completedByWO.put(woId, 0);
        }

        for (WorkOrderLineItem woli : [
            SELECT Id, WorkOrderId, Status
            FROM WorkOrderLineItem
            WHERE WorkOrderId IN :workOrderIds
        ]) {
            Integer total = totalByWO.get(woli.WorkOrderId);
            totalByWO.put(woli.WorkOrderId, total + 1);

            if (completedStatuses.contains(woli.Status)) {
                Integer completed = completedByWO.get(woli.WorkOrderId);
                completedByWO.put(woli.WorkOrderId, completed + 1);
            }
        }

        Map<Id, String> progressByWO = new Map<Id, String>();
        for (Id woId : workOrderIds) {
            Integer total = totalByWO.get(woId);
            Integer completed = completedByWO.get(woId);
            Integer pct = (total > 0) ? (Integer) Math.floor((completed * 100.0) / total) : 0;

            progressByWO.put(woId, buildProgressString(pct, blockCount, displayFormat));
        }

        String saQuery = 'SELECT Id, ParentRecordId, WOLI_Progress__c FROM ServiceAppointment WHERE ParentRecordId IN :workOrderIds';
        List<ServiceAppointment> sasToUpdate = Database.query(saQuery);

        for (ServiceAppointment sa : sasToUpdate) {
            String progress = progressByWO.get(sa.ParentRecordId);
            sa.WOLI_Progress__c = progress;
            if (ganttFieldExists) {
                sa.put('FSL__GanttLabel__c', progress);
            }
        }

        if (!sasToUpdate.isEmpty()) {
            update sasToUpdate;
        }
    }

    private static String buildProgressString(Integer pct, Integer blockCount, String displayFormat) {
        Integer filledCount = (Integer) Math.round((pct / 100.0) * blockCount);
        Integer emptyCount = blockCount - filledCount;

        String blockBar = '[';
        for (Integer i = 0; i < filledCount; i++) {
            blockBar += FILLED_BLOCK;
        }
        for (Integer i = 0; i < emptyCount; i++) {
            blockBar += EMPTY_BLOCK;
        }
        blockBar += ']';

        String pctStr = String.valueOf(pct) + '%';

        if (displayFormat == 'Blocks') {
            return blockBar;
        } else if (displayFormat == 'Percentage') {
            return pctStr;
        } else {
            return blockBar + ' ' + pctStr;
        }
    }

    private static Set<String> parseStatuses(String statusCsv) {
        Set<String> statuses = new Set<String>();
        for (String s : statusCsv.split(',')) {
            String trimmed = s.trim();
            if (String.isNotBlank(trimmed)) {
                statuses.add(trimmed);
            }
        }
        return statuses;
    }
}
