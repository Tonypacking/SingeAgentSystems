import jason.asSyntax.*;
import jason.environment.Environment;
import jason.environment.grid.GridWorldModel;
import jason.environment.grid.GridWorldView;
import jason.environment.grid.Location;

import java.awt.Color;
import java.awt.Font;
import java.awt.Graphics;
import java.util.Random;
import java.util.logging.Logger;

public class MarsEnv extends Environment {

    public static final int GSize = 7; // grid size
    public static final int GARB  = 16; // garbage code in grid model

    public static final Term    ns = Literal.parseLiteral("next(slot)");
    public static final Term    pg = Literal.parseLiteral("pick(garb)");
    public static final Term    dg = Literal.parseLiteral("drop(garb)");
    public static final Term    bg = Literal.parseLiteral("burn(garb)");
    public static final Literal g1 = Literal.parseLiteral("garbage(r1)");
    public static final Literal g2 = Literal.parseLiteral("garbage(r2)");
    public static final Literal g3 = Literal.parseLiteral("garbage(r3)");
    public static final Literal g4 = Literal.parseLiteral("garbage(r4)");

    static Logger logger = Logger.getLogger(MarsEnv.class.getName());

    private MarsModel model;
    private MarsView  view;

    @Override
    public void init(String[] args) {
        model = new MarsModel();
        view  = new MarsView(model);
        model.setView(view);
        updatePercepts();
    }

    private int agIdx(String ag) {
        switch (ag) {
            case "r1": return 0;
            case "r2": return 1;
            case "r3": return 2;
            case "r4": return 3;
            default:   return 0;
        }
    }

    @Override
    public boolean executeAction(String ag, Structure action) {
        logger.info(ag+" doing: "+ action);
        int idx = agIdx(ag);
        try {
            if (action.equals(ns)) {
                model.nextSlot(idx);
            } else if (action.getFunctor().equals("move_towards")) {
                int x = (int)((NumberTerm)action.getTerm(0)).solve();
                int y = (int)((NumberTerm)action.getTerm(1)).solve();
                model.moveTowards(idx, x, y);
            } else if (action.equals(pg)) {
                model.pickGarb(idx);
            } else if (action.equals(dg)) {
                model.dropGarb(idx);
            } else if (action.equals(bg)) {
                model.burnGarb(idx);
            } else {
                return false;
            }
        } catch (Exception e) {
            e.printStackTrace();
        }

        updatePercepts();

        try {
            Thread.sleep(200);
        } catch (Exception e) {}
        informAgsEnvironmentChanged();
        return true;
    }

    /** creates the agents perception based on the MarsModel */
    void updatePercepts() {
        clearPercepts();

        Location r1Loc = model.getAgPos(0);
        Location r2Loc = model.getAgPos(1);
        Location r3Loc = model.getAgPos(2);
        Location r4Loc = model.getAgPos(3);

        Literal pos1 = Literal.parseLiteral("pos(r1," + r1Loc.x + "," + r1Loc.y + ")");
        Literal pos2 = Literal.parseLiteral("pos(r2," + r2Loc.x + "," + r2Loc.y + ")");
        Literal pos3 = Literal.parseLiteral("pos(r3," + r3Loc.x + "," + r3Loc.y + ")");
        Literal pos4 = Literal.parseLiteral("pos(r4," + r4Loc.x + "," + r4Loc.y + ")");

        addPercept(pos1);
        addPercept(pos2);
        addPercept(pos3);
        addPercept(pos4);

        if (model.hasObject(GARB, r1Loc)) {
            addPercept(g1);
        }
        if (model.hasObject(GARB, r2Loc)) {
            addPercept(g2);
        }
        if (model.hasObject(GARB, r3Loc)) {
            addPercept(g3);
        }
        if (model.hasObject(GARB, r4Loc)) {
            addPercept(g4);
        }
    }

    class MarsModel extends GridWorldModel {

        public static final int MErr = 2; // max error in pick garb
        int nerr; // number of tries of pick garb
        boolean[] hasGarb = {false, false, false, false}; // whether each collector is carrying garbage

        Random random = new Random(System.currentTimeMillis());

        private MarsModel() {
            super(GSize, GSize, 4);

            // initial location of agents
            try {
                setAgPos(0, 0, 0);                          // r1 - top-left

                Location r2Loc = new Location(GSize/2, GSize/2);
                setAgPos(1, r2Loc);                         // r2 - center

                Location r3Loc = new Location(GSize-1, GSize-1);
                setAgPos(2, r3Loc);                         // r3 - bottom-right

                Location r4Loc = new Location(0, GSize-1);
                setAgPos(3, r4Loc);                         // r4 - bottom-left
            } catch (Exception e) {
                e.printStackTrace();
            }

            // initial location of garbage
            add(GARB, 3, 0);
            add(GARB, GSize-1, 0);
            add(GARB, 1, 2);
            add(GARB, 0, GSize-2);
            add(GARB, GSize-1, GSize-1);
            add(GARB, GSize-2, GSize-1);
            add(GARB, GSize-1, GSize-2);
            add(GARB, 1, GSize-1);
            add(GARB, 2, GSize-1);
        }

        void nextSlot(int agIdx) throws Exception {
            Location ag = getAgPos(agIdx);
            ag.x++;
            if (ag.x == getWidth()) {
                ag.x = 0;
                ag.y++;
            }
            // finished searching the whole grid
            if (ag.y == getHeight()) {
                return;
            }
            setAgPos(agIdx, ag);
            for (int i = 0; i < 4; i++) if (i != agIdx) setAgPos(i, getAgPos(i));
        }

        void moveTowards(int agIdx, int x, int y) throws Exception {
            Location ag = getAgPos(agIdx);
            if (ag.x < x)       ag.x++;
            else if (ag.x > x)  ag.x--;
            if (ag.y < y)       ag.y++;
            else if (ag.y > y)  ag.y--;
            setAgPos(agIdx, ag);
            for (int i = 0; i < 4; i++) if (i != agIdx) setAgPos(i, getAgPos(i));
        }

        void pickGarb(int agIdx) {
            if (model.hasObject(GARB, getAgPos(agIdx))) {
                // sometimes the "picking" action doesn't work
                // but never more than MErr times
                if (random.nextBoolean() || nerr == MErr) {
                    remove(GARB, getAgPos(agIdx));
                    nerr = 0;
                    hasGarb[agIdx] = true;
                } else {
                    nerr++;
                }
            }
        }
        void dropGarb(int agIdx) {
            if (hasGarb[agIdx]) {
                hasGarb[agIdx] = false;
                add(GARB, getAgPos(agIdx));
            }
        }
        void burnGarb(int agIdx) {
            // agent location has garbage
            if (model.hasObject(GARB, getAgPos(agIdx))) {
                remove(GARB, getAgPos(agIdx));
            }
        }
    }

    class MarsView extends GridWorldView {

        public MarsView(MarsModel model) {
            super(model, "Mars World", 600);
            defaultFont = new Font("Arial", Font.BOLD, 18); // change default font
            setVisible(true);
            repaint();
        }

        /** draw application objects */
        @Override
        public void draw(Graphics g, int x, int y, int object) {
            switch (object) {
            case MarsEnv.GARB:
                drawGarb(g, x, y);
                break;
            }
        }

        @Override
        public void drawAgent(Graphics g, int x, int y, Color c, int id) {
            String label = "R"+(id+1);
            c = Color.blue;
            if (id == 0) {
                c = Color.yellow;
                if (((MarsModel)model).hasGarb[id]) {
                    label += " - G";
                    c = Color.orange;
                }
            }
            super.drawAgent(g, x, y, c, -1);
            if (id == 0) {
                g.setColor(Color.black);
            } else {
                g.setColor(Color.white);
            }
            super.drawString(g, x, y, defaultFont, label);
            repaint();
        }

        public void drawGarb(Graphics g, int x, int y) {
            super.drawObstacle(g, x, y);
            g.setColor(Color.white);
            drawString(g, x, y, defaultFont, "G");
        }

    }
}
