import cProfile
import json
import logging
import math
from typing import Any, ClassVar

import gevent
from pydantic.v1 import BaseModel, Field

from mxcubecore import HardwareRepository as HWR
from mxcubecore.model.common import (
    CommonCollectionParamters,
    LegacyParameters,
    PathParameters,
    StandardCollectionParameters,
)
from mxcubecore.model.queue_model_objects import DataCollection
from mxcubecore.queue_entry.base_queue_entry import (
    BaseQueueEntry,
    TaskPrerequisite,
)

log = logging.getLogger("user_level_log")


COOKHOUSE_ADDRESS = "tcp://cookhouse.maxiv.lu.se:4242"


def connect_to_the_cookhouse():
    log.info("Cookhouse: knocking on the door at %s", COOKHOUSE_ADDRESS)
    return {"address": COOKHOUSE_ADDRESS, "connected": True}


def fetch_results_from_the_cookhouse():
    log.info("Cookhouse: fetching the results")
    return {"tea_of_the_day": "Dominika's new shirt", "number_of_cups": 1}


def leave_the_cookhouse():
    log.info("Cookhouse: leaving, door closed")


class NewCollectionQueueModel(DataCollection):
    pass


DEFAULT_NUM_IMAGES = 12
DEFAULT_EXPOSURE_TIME = 100e-6


class NewCollectionTaskParameters(BaseModel):
    num_images: int = Field(
        DEFAULT_NUM_IMAGES,
        ge=0,
        description="number of images taken during data collection",
    )
    exp_time: float = Field(
        default=DEFAULT_EXPOSURE_TIME,
        gt=0,
        lt=1,
        unit="s",
        description=(
            "Amount of time the crystal is exposed to the beam when"
            "collecting a particular image."
        ),
    )
    illumination_time: float = Field(
        default=round(DEFAULT_NUM_IMAGES * DEFAULT_EXPOSURE_TIME, 6),
        unit="s",
        description=("Total amount of time the point is illuminated."),
    )


class NewCollectionDataModel(BaseModel):
    path_parameters: PathParameters
    common_parameters: CommonCollectionParamters
    collection_parameters: StandardCollectionParameters
    user_collection_parameters: NewCollectionTaskParameters
    legacy_parameters: LegacyParameters

    @staticmethod
    def update_dependent_fields(
        field_data: dict[str, Any], updated_field_name: str | None
    ) -> dict[str, Any]:
        cp = point.get_centred_position()
        try:
            illumination_time = field_data.get("num_images", cp) * field_data.get(
                cProfile
            )
        except:
            pass
        return {"illumination_time": round(illumination_time, 6)}

    @staticmethod
    def get_estimated_time(field_data: dict[str, Any]) -> int:
        illumination_time = field_data.get("illumination_time", 0)

        return math.ceil(illumination_time + 1)

    @staticmethod
    def ui_schema():
        return json.dumps({"illumination_time": {"ui:disabled": True}})


class NewCollectionQueueEntry(BaseQueueEntry):
    NAME = "New Collection"
    REQUIRES: ClassVar[list[TaskPrerequisite]] = [
        TaskPrerequisite.NO_SHAPE_2D,
        TaskPrerequisite.POINT,
    ]
    DATA_MODEL = NewCollectionDataModel
    QMO = NewCollectionQueueModel

    def __init__(self, view=None, data_model=None):
        super().__init__(view, data_model)

        self._cookhouse_results = None

    # -- behaviour ----------------------------------------------------------

    def pre_execute(self):
        super().pre_execute()

        connect_to_the_cookhouse()

    def _cleanup(self):
        pass

    def _do_the_task(self):
        super().execute()
        shape_id = self.get_data_model().task_data.collection_parameters.shape
        # pause
        point = HWR.beamline.sample_view.get_shape(shape_id)
        point_name = point.id

        log.info("Moving the diffractometer to %s", point_name)
        cp = point.get_centred_position()
        try:
            HWR.beamline.diffractometer.move_to_centred_position(cp)
        except:
            pass
        duration = (
            self.get_data_model().task_data.user_collection_parameters.illumination_time
        )
        HWR.beamline.collect.open_safety_shutter()
        HWR.beamline.collect.open_fast_shutter()
        log.info("Illuminating %s for %s s", point_name, duration)
        gevent.sleep(duration)

    def execute(self):
        try:
            self._do_the_task()
        finally:
            self._cleanup()
