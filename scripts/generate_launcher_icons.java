import java.awt.BasicStroke;
import java.awt.Color;
import java.awt.Graphics2D;
import java.awt.RenderingHints;
import java.awt.geom.Ellipse2D;
import java.awt.geom.Path2D;
import java.awt.geom.RoundRectangle2D;
import java.awt.image.BufferedImage;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.LinkedHashMap;
import java.util.Map;
import javax.imageio.ImageIO;

final class GenerateLauncherIcons {
    private static final int SUPERSAMPLING = 4;
    private static final double VIEWPORT = 108.0;
    private static final Color BACKGROUND = Color.decode("#0B1020");
    private static final Color PROMPT = Color.decode("#818CF8");
    private static final Color MONOGRAM = Color.decode("#F8FAFC");
    private static final Color CURSOR = Color.decode("#22D3EE");

    private GenerateLauncherIcons() {}

    public static void main(String[] args) throws IOException {
        Path resourceRoot = args.length == 0
                ? Path.of("flutter_app/android/app/src/main/res")
                : Path.of(args[0]);
        Map<String, Integer> sizes = new LinkedHashMap<>();
        sizes.put("mdpi", 48);
        sizes.put("hdpi", 72);
        sizes.put("xhdpi", 96);
        sizes.put("xxhdpi", 144);
        sizes.put("xxxhdpi", 192);

        for (Map.Entry<String, Integer> target : sizes.entrySet()) {
            Path outputDirectory = resourceRoot.resolve("mipmap-" + target.getKey());
            Files.createDirectories(outputDirectory);
            writeIcon(outputDirectory.resolve("ic_launcher.png"), target.getValue(), false);
            writeIcon(outputDirectory.resolve("ic_launcher_round.png"), target.getValue(), true);
        }
    }

    private static void writeIcon(Path output, int size, boolean round) throws IOException {
        int canvasSize = size * SUPERSAMPLING;
        BufferedImage canvas = new BufferedImage(
                canvasSize,
                canvasSize,
                BufferedImage.TYPE_INT_ARGB
        );
        Graphics2D graphics = canvas.createGraphics();
        configureGraphics(graphics);
        double scale = canvasSize / VIEWPORT;

        graphics.setColor(BACKGROUND);
        double edge = scale;
        double extent = canvasSize - (2 * edge);
        if (round) {
            graphics.fill(new Ellipse2D.Double(edge, edge, extent, extent));
        } else {
            double corner = 23 * scale;
            graphics.fill(new RoundRectangle2D.Double(
                    edge,
                    edge,
                    extent,
                    extent,
                    corner * 2,
                    corner * 2
            ));
        }

        graphics.setStroke(new BasicStroke(
                (float) (8 * scale),
                BasicStroke.CAP_ROUND,
                BasicStroke.JOIN_ROUND
        ));

        Path2D prompt = new Path2D.Double();
        prompt.moveTo(22 * scale, 35 * scale);
        prompt.lineTo(39 * scale, 54 * scale);
        prompt.lineTo(22 * scale, 73 * scale);
        graphics.setColor(PROMPT);
        graphics.draw(prompt);

        Path2D monogram = new Path2D.Double();
        monogram.moveTo(47 * scale, 73 * scale);
        monogram.lineTo(47 * scale, 35 * scale);
        monogram.lineTo(60 * scale, 53 * scale);
        monogram.lineTo(73 * scale, 35 * scale);
        monogram.lineTo(73 * scale, 73 * scale);
        graphics.setColor(MONOGRAM);
        graphics.draw(monogram);

        Path2D cursor = new Path2D.Double();
        cursor.moveTo(81 * scale, 73 * scale);
        cursor.lineTo(87 * scale, 73 * scale);
        graphics.setColor(CURSOR);
        graphics.draw(cursor);
        graphics.dispose();

        BufferedImage icon = new BufferedImage(size, size, BufferedImage.TYPE_INT_ARGB);
        Graphics2D outputGraphics = icon.createGraphics();
        configureGraphics(outputGraphics);
        outputGraphics.drawImage(canvas, 0, 0, size, size, null);
        outputGraphics.dispose();
        ImageIO.write(icon, "png", output.toFile());
    }

    private static void configureGraphics(Graphics2D graphics) {
        graphics.setRenderingHint(
                RenderingHints.KEY_ANTIALIASING,
                RenderingHints.VALUE_ANTIALIAS_ON
        );
        graphics.setRenderingHint(
                RenderingHints.KEY_INTERPOLATION,
                RenderingHints.VALUE_INTERPOLATION_BICUBIC
        );
        graphics.setRenderingHint(
                RenderingHints.KEY_RENDERING,
                RenderingHints.VALUE_RENDER_QUALITY
        );
        graphics.setRenderingHint(
                RenderingHints.KEY_STROKE_CONTROL,
                RenderingHints.VALUE_STROKE_PURE
        );
    }
}
