package arch;

import jason.architecture.AgArch;
import jason.asSemantics.ActionExec;
import jason.asSemantics.Message;
import jason.asSyntax.Literal;
import jason.runtime.RuntimeServices;

import java.util.Collection;
import java.util.Map;
import java.util.logging.Logger;

public class SkibidyAgent extends AgArch {

    private static final Logger logger = Logger.getLogger(SkibidyAgent.class.getName());

    @Override
    public void init() throws Exception {
        super.init();
        logger.info("SkibidyAgent initialized.");
    }

    @Override
    public void stop() {
        super.stop();
    }

    @Override
    public void reasoningCycleStarting() {
        super.reasoningCycleStarting();
    }

    @Override
    public void reasoningCycleFinished() {
        super.reasoningCycleFinished();
    }

    @Override
    public Collection<Literal> perceive() {
        return super.perceive();
    }

    @Override
    public void checkMail() {
        super.checkMail();
    }

    @Override
    public void act(ActionExec action) {
        super.act(action);
    }

    @Override
    public boolean canSleep() {
        return super.canSleep();
    }

    @Override
    public void wake() {
        super.wake();
    }

    @Override
    public void wakeUpSense() {
        super.wakeUpSense();
    }

    @Override
    public void wakeUpDeliberate() {
        super.wakeUpDeliberate();
    }

    @Override
    public void wakeUpAct() {
        super.wakeUpAct();
    }

    @Override
    public RuntimeServices getRuntimeServices() {
        return super.getRuntimeServices();
    }

    @Override
    public String getAgName() {
        return super.getAgName();
    }

    @Override
    public void sendMsg(Message m) throws Exception {
        super.sendMsg(m);
    }

    @Override
    public void broadcast(Message m) throws Exception {
        super.broadcast(m);
    }

    @Override
    public boolean isRunning() {
        return super.isRunning();
    }

    @Override
    public Map<String, Object> getStatus() {
        return super.getStatus();
    }
}
