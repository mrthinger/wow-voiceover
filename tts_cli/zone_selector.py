import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
import numpy as np


class ZoneSelector:
    def __init__(self, image_path, x_scale, y_scale, x_offset, y_offset):
        self.image_path = image_path
        self.x_scale = x_scale
        self.y_scale = y_scale
        self.x_offset = x_offset
        self.y_offset = y_offset
        self.start_point = None
        self.end_point = None
        self.rect = Rectangle((0, 0), 0, 0, linewidth=1,
                              edgecolor='r', facecolor='none')
        self.drawing = False
        self.confirm_fig = None
        self.confirm_rect = None

    def image_to_game_coordinates(self, x, y):
        game_x = x * self.x_scale + self.x_offset
        game_y = y * self.y_scale + self.y_offset
        return game_x, game_y

    def on_click(self, event):
        if not self.drawing:
            self.start_point = (event.xdata, event.ydata)
            self.drawing = True
            self.rect.set_width(0)
            self.rect.set_height(0)

    def on_release(self, event):
        if self.drawing and event.xdata is not None and event.ydata is not None:
            self.end_point = (event.xdata, event.ydata)
            self.rect.set_width(self.end_point[0] - self.start_point[0])
            self.rect.set_height(self.end_point[1] - self.start_point[1])
            self.rect.set_xy(self.start_point)
            plt.draw()

            # Show confirmation window
            self.show_confirmation_window()

    def on_motion(self, event):
        if self.drawing and event.xdata is not None and event.ydata is not None:
            width = event.xdata - self.start_point[0]
            height = event.ydata - self.start_point[1]
            self.rect.set_xy(self.start_point)
            self.rect.set_width(width)
            self.rect.set_height(height)
            plt.draw()

    def show_confirmation_window(self):
        plt.close(self.fig)
        self.confirm_fig, ax = plt.subplots()
        img = plt.imread(self.image_path)
        ax.imshow(img)

        self.confirm_rect = Rectangle(self.start_point, self.rect.get_width(), self.rect.get_height(),
                                      linewidth=2, edgecolor='g', facecolor='none')
        ax.add_patch(self.confirm_rect)

        self.ok_button_ax = self.confirm_fig.add_axes([0.7, 0.05, 0.1, 0.075])
        self.ok_button = plt.Button(self.ok_button_ax, 'OK')
        self.ok_button.on_clicked(self.confirm_selection)

        self.try_again_button_ax = self.confirm_fig.add_axes([0.81, 0.05, 0.1, 0.075])
        self.try_again_button = plt.Button(
            self.try_again_button_ax, 'Try Again')
        self.try_again_button.on_clicked(self.cancel_selection)

        plt.show()

    def confirm_selection(self, event):
        plt.close(self.confirm_fig)

        game_start_point = self.image_to_game_coordinates(
            *self.start_point)
        game_end_point = self.image_to_game_coordinates(*self.end_point)
        x_min = min(game_start_point[0], game_end_point[0])
        x_max = max(game_start_point[0], game_end_point[0])
        y_min = min(game_start_point[1], game_end_point[1])
        y_max = max(game_start_point[1], game_end_point[1])

        self.coordinate_ranges = ((y_min, y_max), (x_min, x_max))
        self.drawing = False

    def cancel_selection(self, event):
        plt.close(self.confirm_fig)
        new_fig = plt.figure()
        new_manager = new_fig.canvas.manager
        new_manager.canvas.figure = self.fig
        self.fig.set_canvas(new_manager.canvas)
        plt.show()
        self.drawing = False

    def select_zone(self):
        """
        Displays the map and allows the user to select a zone by drawing a rectangle.
        After selecting the zone, a confirmation window appears with the selected zone
        and options to confirm or try again.

        Returns:
            tuple: A tuple containing two tuples representing the coordinate ranges in the form
                   ((x_min, x_max), (y_min, y_max)).
        """
        self.fig = plt.figure()

        # Create a new axes for the image
        img_ax = self.fig.add_axes([0.1, 0.1, 0.8, 0.8])
        img = plt.imread(self.image_path)
        if img.dtype == np.uint8:
            img = img.astype(np.float32) / 255.0  # Normalize if image is in uint8 format
        img_ax.imshow(img)
        img_ax.add_patch(self.rect)

        # Attach event listeners to the image axes
        img_ax.figure.canvas.mpl_connect('button_press_event', self.on_click)
        img_ax.figure.canvas.mpl_connect(
            'button_release_event', self.on_release)
        img_ax.figure.canvas.mpl_connect('motion_notify_event', self.on_motion)

        plt.show()
        return self.coordinate_ranges


def compute_scaling_factors(image_points, game_points):
    assert len(image_points) == len(
        game_points), "The number of image points and game points must be the same."

    A = np.array([[image_points[i][0], 1] for i in range(len(image_points))])
    B = np.array([game_points[i][0] for i in range(len(game_points))])

    x_scale, x_offset = np.linalg.lstsq(A, B, rcond=None)[0]

    A = np.array([[image_points[i][1], 1] for i in range(len(image_points))])
    B = np.array([game_points[i][1] for i in range(len(game_points))])

    y_scale, y_offset = np.linalg.lstsq(A, B, rcond=None)[0]

    return x_scale, y_scale, x_offset, y_offset


class KalimdorZoneSelector(ZoneSelector):
    def __init__(self):
        image_points = [
            (433.2499999999999, 458.5),
            (358.5153846153844, 139.62307692307684),
            (211.1923076923075, 332.36153846153843)
        ]

        game_points = [
            (-4251.33, -607.434),
            (-2216.35, 7848.3),
            (1466.45, 2682.83)
        ]

        x_scale, y_scale, x_offset, y_offset = compute_scaling_factors(
            image_points, game_points)

        image_path = 'assets/images/kalimdor.jpg'
        super().__init__(image_path, x_scale, y_scale, x_offset, y_offset)


class EasternKingdomsZoneSelector(ZoneSelector):
    def __init__(self):
        image_points = [
            (444.49999999999983, 166.0),
            (219.49999999999994, 820.75),
            (349.99999999999994, 472.0)
        ]

        game_points = [
            (-5345.39, 2269.85),
            (464.101, -14477.9),
            (-2929.87, -5424.85),
        ]

        x_scale, y_scale, x_offset, y_offset = compute_scaling_factors(
            image_points, game_points)

        image_path = 'assets/images/easternkingdoms.jpg'
        super().__init__(image_path, x_scale, y_scale, x_offset, y_offset)