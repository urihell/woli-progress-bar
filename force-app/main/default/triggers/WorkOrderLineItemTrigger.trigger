trigger WorkOrderLineItemTrigger on WorkOrderLineItem (
    after insert,
    after update,
    after delete,
    after undelete
) {
    WOLIProgressHandler.handleProgress(Trigger.new, Trigger.old);
}
