#import "@preview/touying:0.7.4": *
#import themes.metropolis: *

#set raw(theme: "catppuccin-latte.tmTheme")
#set text(font: "Roboto")

#show: metropolis-theme.with(
  aspect-ratio: "16-9",

  header: self => {
    smallcaps(
      utils.display-current-heading(
        setting: utils.fit-to-width.with(grow: false, 100%)
      )
    )
  },

  footer: self => self.info.institution,

  config-info(
    title: smallcaps[MXCuBE Custom Tasks],
    subtitle: [Quite confusing, quite technical],
    author: [Paweł Moćko],
    date: datetime.today(),
  ),
  config-colors(
    primary: rgb("#8839ef"),          // Mauve
    // primary-light: rgb("#ccd0da"),    // Surface 0
    secondary: rgb("#df8e1d"),        // Subtext 1
    neutral-lightest: rgb("#eff1f5"), // Base
    // neutral-dark: rgb("#5c5f77"),     // Subtext 1
    neutral-darkest: rgb("#4c4f69"),  // Text
  )
)




#title-slide()

== What is the purpose

Custom tasks allow us to write custom experiments in MXCuBE that may be
specific to our site, or would be tricky to share with others. They allow us to:

- avoid modifying shared code
- develop our own experiments without appeasing other facilities ;)
- they can be easily tweaked by the beamline staff if need be

---

== How

To create a new form, there are two important pieces to implement:

- *`DATA_MODEL`* — a `Pydantic` model describing:
  - data that is supposed to come from the web app
  - what form fields will be displayed in the web app & their constraints
  - form layout

- *`QueueEntry`* — a derived class from `BaseQueueEntry`, needs 3 methods:
  - `pre_exeucute` — setup for the task
  - `execute` — actual logic to perform the task
  - `post_execute` — cleanup after the task is finished / fails.

---


==

#align(center + horizon)[
  #text(size: 28pt, weight: "medium")[
    Creating your own task
  ]
]

== Some boilerplate -- Data Model
Just a plain Pydantic model :)

#touying-raw(```python
from pydantic import BaseModel, Field

class NewCollectionTaskParameters(BaseModel):
    num_images: int = Field(...) # ellipsis marks required fields.
    exp_time: float = Field(...)

```)

---

Which we can annotate:
#touying-raw(```python
class NewCollectionTaskParameters(BaseModel):
    num_images: int = Field(
        ..., ge=0, description="number of images taken during data collection"
    )
    exposure_time: float = Field(
        default=100e-6,
        gt=0,
        lt=1,
        unit="s",
        description=(
          "Amount of time the crystal is exposed to the beam when"
          "collecting a particular image."
        ),
    )
```)

---

And we need to put some properties that are always required...
#touying-raw(```python
class NewCollectionDataModel(BaseModel):
    path_parameters: PathParameters
    common_parameters: CommonCollectionParamters
    collection_parameters: StandardCollectionParameters
    user_collection_parameters: NewCollectionTaskParameters
    legacy_parameters: LegacyParameters
    # pause
    # and there is one required bit, to be explained later :)
    @staticmethod
    def update_dependent_fields(field_data: NewCollectionTaskParameters):
        return {}
```)

== Some boilerplate -- Queue Model
This is quite a weird detail.

For each `QueueEntry`, there needs to be a `QueueModel` class
in a 1:1 correspondence, usually it looks like this:

#touying-raw(```python
from mxcubecore.model.queue_model_objects import DataCollection

class NewCollectionQueueModel(DataCollection):
    pass
```)

---

== Some boilerplate -- wiring it all together


#touying-raw(```python
# new_collection.py
from mxcubecore.queue_entry.base_queue_entry import BaseQueueEntry

# class name has to match filename
class NewCollectionQueueEntry(BaseQueueEntry): 
    NAME = "New Collection" # name in the context menu
```)



---
#touying-raw(```python
from mxcubecore.queue_entry.base_queue_entry import BaseQueueEntry, TaskPrerequisite

class NewCollectionQueueEntry(BaseQueueEntry): 
    NAME = "New Collection"
    REQUIRES = [
        TaskPrerequisite.NO_SHAPE_2D,
        TaskPrerequisite.POINT,
    ]
    # pause
    QMO = NewCollectionQueueModel
    # pause
    DATA_MODEL = NewCollectionDataModel
```)
---

Then enable it in the `beamline.yaml` config file:
#touying-raw(```yaml
# ...

available_methods:
    new_collection: true
    # ...
```)

#let note(body) = block(
  width: 100%,
  fill: rgb("#dce0e8"),
  stroke: (left: 3pt + rgb("#df8e1d")),
  inset: 12pt,
  radius: 4pt,
  body,
)

#note[
  the above key matches the name of the file containing `NewCollectionQueueEntry`
]

---
And we should get something like this:

#image("new_collection.png", width: 80%)

---
== Defining UI layout
To change looks of a form, we can write a `ui_schema` method.
the customization options include:
- order of inputs
- widgets used for inputs (e.g. dropdown menu, text input, number input, ...)
- layout (width of a particular input)
- grouping inputs
- splitting groups of inputs into rows (MAX IV only code, it will definitely change "soon")
#touying-raw(```python
class NewCollectionDataModel(BaseModel):
    # ...
    @staticmethod
    def ui_schema():
        return json.dumps({
                "ui:order": [ "num_images", "exposure_time"],
            })
```)

--- 

== Defining UI Layout -- Example 2

#touying-raw(```python
    @staticmethod
    def ui_schema():
        processing_group = {"group": "Processing"}
        col_4 = {"col": 4}
        processing_ui_options = {"ui:options": {**processing_group, **col_4}}
        return json.dumps(
            {
                "cell_a": processing_ui_options,
                "cell_b": processing_ui_options,
                "cell_c": processing_ui_options,
                "cell_alpha": processing_ui_options,
                "cell_beta": processing_ui_options,
                "cell_gamma": processing_ui_options,
            }
        )
```)

== Adding some behaviour

And for the task to do something, it's time to define an `execute` method.

#touying-raw(```python


```)

---

== Limitations
- On the upstream version of mxcube, the custom tasks are currently broken (thanks to some huge refactor I've approved :))
- There is currently no way of showing custom errors / warnings. Only generic ones like "num_images has to be > 0".

