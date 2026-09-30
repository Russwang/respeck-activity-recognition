# Course context and attribution

This project originated in **Principles and Design of IoT Systems**, School of Informatics, University of Edinburgh, academic year 2025–26 (PG INFR11150 / UG INFR11239).

Source reviewed: the user-supplied *Principles and Design of IoT Systems Course Outline*, version 1.1, dated 11 September 2025. The original PDF is not redistributed in this repository.

## What the outline establishes

- Pages 1–2 describe a wearable IMU with a three-axis accelerometer and a supplied Android data-collection app. Students extend this into a real-time recognition system.
- Pages 3–4 describe data collection and classification of physical activities and social signals; the implementation is group coursework.
- Page 5 asks for a working prototype, architecture, algorithms, app design and quantitative performance evidence.
- Pages 5–6 describe the final report, including methods, testing, benchmarks and reflection.

## This repository's actual scope

| Course requirement | Evidence in this repository | Limitation |
| --- | --- | --- |
| 12 physical activities, including separate sitting and standing | 11 model outputs and corresponding historical label mapping | Sitting/standing are merged |
| Six social signals during stationary activities | Four outputs: normal breathing, coughing, hyperventilation, other | Talking, singing, laughing and eating are not independent output classes; inference is not currently gated to stationary predictions |
| Real-time Android integration | Flutter BLE decoding, buffering, TFLite calls and result display | Revised app still needs a sensor/phone end-to-end test |
| Quantitative performance evaluation | Historical cross-validation reports and confusion matrices | No refreshed accuracy, device latency, power, CPU or memory benchmark |
| Demonstration and report | Source and models present | Original demo recording, slides and final report not supplied |

The original collection app is preserved under `pdiot_har_example/`; its original README remains in that directory. Training, inference integration and application extensions are the project work described by this portfolio. Exact individual/team contribution boundaries should be supported by the original report or development records, which are not present here.

No blanket open-source license is asserted for the supplied course scaffold. Upstream code and dependencies retain their respective rights; an original upstream repository/license file would help document reuse terms precisely.
