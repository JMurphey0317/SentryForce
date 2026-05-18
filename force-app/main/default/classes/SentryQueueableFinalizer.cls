public virtual class SentryQueueableFinalizer implements System.Finalizer {
    public virtual void execute(System.FinalizerContext finalizerContext) {
        if (finalizerContext.getResult() == System.ParentJobResult.UNHANDLED_EXCEPTION) {
            Exception capturedException = finalizerContext.getException();
            if (capturedException != null) {
                SentryMonitor.exception('QueueableFinalizer', capturedException);
            }
        }
        innerExecute(finalizerContext);
    }

    protected virtual void innerExecute(System.FinalizerContext finalizerContext) {
    }
}
