
--
-- TOC entry 219 (class 1259 OID 31354)
-- Name: datastreams; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.datastreams (
    id bigint NOT NULL,
    name character varying,
    definition jsonb
);


ALTER TABLE public.datastreams OWNER TO postgres;

--
-- TOC entry 220 (class 1259 OID 31360)
-- Name: device_datastreams; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.device_datastreams (
    device_id bigint NOT NULL,
    datastream_id bigint NOT NULL
);


ALTER TABLE public.device_datastreams OWNER TO postgres;

--
-- TOC entry 222 (class 1259 OID 31377)
-- Name: device_definitions; Type: VIEW; Schema: public; Owner: postgres
--

CREATE VIEW public.device_definitions AS
SELECT
    NULL::bigint AS device_id,
    NULL::character varying AS device_name,
    NULL::character varying AS device_description,
    NULL::character varying AS device_ext_id,
    NULL::jsonb AS device_location,
    NULL::jsonb AS definitions;


ALTER VIEW public.device_definitions OWNER TO postgres;

--
-- TOC entry 221 (class 1259 OID 31365)
-- Name: devices; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.devices (
    id bigint NOT NULL,
    name character varying,
    description character varying,
    ext_id character varying,
    location jsonb
);


ALTER TABLE public.devices OWNER TO postgres;

--
-- TOC entry 3456 (class 0 OID 31354)
-- Dependencies: 219
-- Data for Name: datastreams; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.datastreams VALUES (1, 'humidity', '{"name": "relativeHumidity", "Sensor": {"name": "Humidity Sensor", "metadata": "https://www.ecowitt.com/shop/goodsDetail/102", "description": "Ecowitt WS Humidity", "encodingType": "PDF"}, "description": "", "observationType": "http://www.opengis.net/def/observationType/OGC-OM/2.0/OM_Measurement", "ObservedProperty": {"name": "Luftfeuchtigkeit", "definition": "", "description": ""}, "unitOfMeasurement": {"name": "percent", "symbol": "%", "definition": "http://unitsofmeasure.org/ucum.html#para-30"}}');
INSERT INTO public.datastreams VALUES (2, 'tempf', '{"name": "temperature", "Sensor": {"name": "Temperature Sensor", "metadata": "https://www.ecowitt.com/shop/goodsDetail/102", "description": "Ecowitt WS Temperature", "encodingType": "PDF"}, "description": "", "observationType": "http://www.opengis.net/def/observationType/OGC-OM/2.0/OM_Measurement", "ObservedProperty": {"name": "Temperatur", "definition": "", "description": ""}, "unitOfMeasurement": {"name": "degree Celsius", "symbol": "°C", "definition": "http://unitsofmeasure.org/ucum.html#para-30"}}');
INSERT INTO public.datastreams VALUES (3, 'baromabsin', '{"name": "atmosphericPressure", "Sensor": {"name": "Pressure Sensor", "metadata": "https://www.ecowitt.com/shop/goodsDetail/102", "description": "Ecowitt WS Pressure", "encodingType": "PDF"}, "description": "", "observationType": "http://www.opengis.net/def/observationType/OGC-OM/2.0/OM_Measurement", "ObservedProperty": {"name": "Absoluter barometrischer Druck", "definition": "", "description": ""}, "unitOfMeasurement": {"name": "pascal", "symbol": "Pa", "definition": "http://unitsofmeasure.org/ucum.html#para-30"}}');
INSERT INTO public.datastreams VALUES (11, '1-0:32.7.0', '{"name": "1-0:32.7.0", "Sensor": {"name": "1-0:32.7.0", "metadata": "", "description": "1-0:32.7.0", "encodingType": "PDF"}, "description": "", "observationType": "http://www.opengis.net/def/observationType/OGC-OM/2.0/OM_Measurement", "ObservedProperty": {"name": "V", "definition": "", "description": ""}, "unitOfMeasurement": {"name": "V", "symbol": "V", "definition": "http://unitsofmeasure.org/ucum.html#para-30"}}');
INSERT INTO public.datastreams VALUES (12, '1-0:52.7.0', '{"name": "1-0:52.7.0", "Sensor": {"name": "1-0:52.7.0", "metadata": "", "description": "1-0:52.7.0", "encodingType": "PDF"}, "description": "", "observationType": "http://www.opengis.net/def/observationType/OGC-OM/2.0/OM_Measurement", "ObservedProperty": {"name": "V", "definition": "", "description": ""}, "unitOfMeasurement": {"name": "V", "symbol": "V", "definition": "http://unitsofmeasure.org/ucum.html#para-30"}}');
INSERT INTO public.datastreams VALUES (13, '1-0:72.7.0', '{"name": "1-0:72.7.0", "Sensor": {"name": "1-0:72.7.0", "metadata": "", "description": "1-0:72.7.0", "encodingType": "PDF"}, "description": "", "observationType": "http://www.opengis.net/def/observationType/OGC-OM/2.0/OM_Measurement", "ObservedProperty": {"name": "V", "definition": "", "description": ""}, "unitOfMeasurement": {"name": "V", "symbol": "V", "definition": "http://unitsofmeasure.org/ucum.html#para-30"}}');
INSERT INTO public.datastreams VALUES (14, '1-0:16.7.0', '{"name": "1-0:16.7.0", "Sensor": {"name": "1-0:16.7.0", "metadata": "", "description": "1-0:16.7.0", "encodingType": "PDF"}, "description": "", "observationType": "http://www.opengis.net/def/observationType/OGC-OM/2.0/OM_Measurement", "ObservedProperty": {"name": "V", "definition": "", "description": ""}, "unitOfMeasurement": {"name": "V", "symbol": "V", "definition": "http://unitsofmeasure.org/ucum.html#para-30"}}');
INSERT INTO public.datastreams VALUES (15, '1-0:36.7.0', '{"name": "1-0:36.7.0", "Sensor": {"name": "1-0:36.7.0", "metadata": "", "description": "1-0:36.7.0", "encodingType": "PDF"}, "description": "", "observationType": "http://www.opengis.net/def/observationType/OGC-OM/2.0/OM_Measurement", "ObservedProperty": {"name": "V", "definition": "", "description": ""}, "unitOfMeasurement": {"name": "V", "symbol": "V", "definition": "http://unitsofmeasure.org/ucum.html#para-30"}}');
INSERT INTO public.datastreams VALUES (16, '1-0:56.7.0', '{"name": "1-0:56.7.0", "Sensor": {"name": "1-0:56.7.0", "metadata": "", "description": "1-0:56.7.0", "encodingType": "PDF"}, "description": "", "observationType": "http://www.opengis.net/def/observationType/OGC-OM/2.0/OM_Measurement", "ObservedProperty": {"name": "V", "definition": "", "description": ""}, "unitOfMeasurement": {"name": "V", "symbol": "V", "definition": "http://unitsofmeasure.org/ucum.html#para-30"}}');
INSERT INTO public.datastreams VALUES (17, '1-0:32.7.0', '{"name": "1-0:76.7.0", "Sensor": {"name": "1-0:76.7.0", "metadata": "", "description": "1-0:76.7.0", "encodingType": "PDF"}, "description": "", "observationType": "http://www.opengis.net/def/observationType/OGC-OM/2.0/OM_Measurement", "ObservedProperty": {"name": "V", "definition": "", "description": ""}, "unitOfMeasurement": {"name": "V", "symbol": "V", "definition": "http://unitsofmeasure.org/ucum.html#para-30"}}');
INSERT INTO public.datastreams VALUES (18, '1-0:51.7.0', '{"name": "1-0:51.7.0", "Sensor": {"name": "1-0:51.7.0", "metadata": "", "description": "1-0:51.7.0", "encodingType": "PDF"}, "description": "", "observationType": "http://www.opengis.net/def/observationType/OGC-OM/2.0/OM_Measurement", "ObservedProperty": {"name": "V", "definition": "", "description": ""}, "unitOfMeasurement": {"name": "V", "symbol": "V", "definition": "http://unitsofmeasure.org/ucum.html#para-30"}}');
INSERT INTO public.datastreams VALUES (19, '1-0:31.7.0', '{"name": "1-0:31.7.0", "Sensor": {"name": "1-0:31.7.0", "metadata": "", "description": "1-0:31.7.0", "encodingType": "PDF"}, "description": "", "observationType": "http://www.opengis.net/def/observationType/OGC-OM/2.0/OM_Measurement", "ObservedProperty": {"name": "V", "definition": "", "description": ""}, "unitOfMeasurement": {"name": "V", "symbol": "V", "definition": "http://unitsofmeasure.org/ucum.html#para-30"}}');
INSERT INTO public.datastreams VALUES (10, '1-0:71.7.0', '{"name": "1-0:71.7.0", "Sensor": {"name": "1-0:71.7.0", "metadata": "", "description": "1-0:71.7.0", "encodingType": "PDF"}, "description": "", "observationType": "http://www.opengis.net/def/observationType/OGC-OM/2.0/OM_Measurement", "ObservedProperty": {"name": "V", "definition": "", "description": ""}, "unitOfMeasurement": {"name": "V", "symbol": "V", "definition": "http://unitsofmeasure.org/ucum.html#para-30"}}');
INSERT INTO public.datastreams VALUES (20, '1-0:14.7.0', '{"name": "1-0:14.7.0", "Sensor": {"name": "1-0:14.7.0", "metadata": "", "description": "1-0:14.7.0", "encodingType": "PDF"}, "description": "", "observationType": "http://www.opengis.net/def/observationType/OGC-OM/2.0/OM_Measurement", "ObservedProperty": {"name": "V", "definition": "", "description": ""}, "unitOfMeasurement": {"name": "V", "symbol": "V", "definition": "http://unitsofmeasure.org/ucum.html#para-30"}}');


--
-- TOC entry 3457 (class 0 OID 31360)
-- Dependencies: 220
-- Data for Name: device_datastreams; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.device_datastreams VALUES (1, 3);
INSERT INTO public.device_datastreams VALUES (1, 2);
INSERT INTO public.device_datastreams VALUES (1, 1);
INSERT INTO public.device_datastreams VALUES (11, 11);
INSERT INTO public.device_datastreams VALUES (11, 12);
INSERT INTO public.device_datastreams VALUES (11, 13);
INSERT INTO public.device_datastreams VALUES (11, 14);
INSERT INTO public.device_datastreams VALUES (11, 15);
INSERT INTO public.device_datastreams VALUES (11, 16);
INSERT INTO public.device_datastreams VALUES (11, 17);
INSERT INTO public.device_datastreams VALUES (11, 18);
INSERT INTO public.device_datastreams VALUES (11, 19);
INSERT INTO public.device_datastreams VALUES (11, 20);
INSERT INTO public.device_datastreams VALUES (12, 11);
INSERT INTO public.device_datastreams VALUES (12, 12);
INSERT INTO public.device_datastreams VALUES (12, 13);
INSERT INTO public.device_datastreams VALUES (12, 14);
INSERT INTO public.device_datastreams VALUES (12, 15);
INSERT INTO public.device_datastreams VALUES (12, 16);
INSERT INTO public.device_datastreams VALUES (12, 17);
INSERT INTO public.device_datastreams VALUES (12, 18);
INSERT INTO public.device_datastreams VALUES (12, 19);
INSERT INTO public.device_datastreams VALUES (12, 20);
INSERT INTO public.device_datastreams VALUES (13, 11);
INSERT INTO public.device_datastreams VALUES (13, 12);
INSERT INTO public.device_datastreams VALUES (13, 13);
INSERT INTO public.device_datastreams VALUES (13, 14);
INSERT INTO public.device_datastreams VALUES (13, 15);
INSERT INTO public.device_datastreams VALUES (13, 16);
INSERT INTO public.device_datastreams VALUES (13, 17);
INSERT INTO public.device_datastreams VALUES (13, 18);
INSERT INTO public.device_datastreams VALUES (13, 19);
INSERT INTO public.device_datastreams VALUES (13, 20);


--
-- TOC entry 3458 (class 0 OID 31365)
-- Dependencies: 221
-- Data for Name: devices; Type: TABLE DATA; Schema: public; Owner: postgres
--

INSERT INTO public.devices VALUES (1, 'Wetterstation Bielefeld', 'Wetterstation in Bielefeld', 'BCB57A2838A90E31BA1F61139D74EFE6', '{"type": "Point", "coordinates": [8.531689, 51.952503]}');
INSERT INTO public.devices VALUES (11, 'Sensor Gateway GWTS9901845601', 'Gatway GWTS9901845605, Meter 9ISK0007463801', 'GWTS9901845601', '{"type": "Point", "coordinates": [7.639286227368158, 51.95226057725515]}');
INSERT INTO public.devices VALUES (12, 'Sensor Gateway GWTS9901845602', 'Gatway GWTS9901845605, Meter 9ISK0007463802', 'GWTS9901845602', '{"type": "Point", "coordinates": [7.639292262338146, 51.95233455311639]}');
INSERT INTO public.devices VALUES (13, 'Sensor Gateway GWTS9901845603', 'Gatway GWTS9901845605, Meter 9ISK0007463803', 'GWTS9901845603', '{"type": "Point", "coordinates": [7.639532990585516, 51.95233496638901]}');
INSERT INTO public.devices VALUES (14, 'Sensor Gateway GWTS9901845604', 'Gatway GWTS9901845605, Meter 9ISK0007463804', 'GWTS9901845604', '{"type": "Point", "coordinates": [7.638963691749818, 51.95229322583466]}');
INSERT INTO public.devices VALUES (15, 'Sensor Gateway GWTS9901845605', 'Gatway GWTS9901845605, Meter 9ISK0007463805', 'GWTS9901845605', '{"type": "Point", "coordinates": [7.639080367836287, 51.952179162339476]}');


--
-- TOC entry 3301 (class 2606 OID 31372)
-- Name: datastreams datastreams_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.datastreams
    ADD CONSTRAINT datastreams_pkey PRIMARY KEY (id);


--
-- TOC entry 3303 (class 2606 OID 31374)
-- Name: device_datastreams device_datastreams_pk; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.device_datastreams
    ADD CONSTRAINT device_datastreams_pk PRIMARY KEY (device_id, datastream_id);


--
-- TOC entry 3305 (class 2606 OID 31376)
-- Name: devices devices_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.devices
    ADD CONSTRAINT devices_pkey PRIMARY KEY (id);


--
-- TOC entry 3455 (class 2618 OID 31380)
-- Name: device_definitions _RETURN; Type: RULE; Schema: public; Owner: postgres
--

CREATE OR REPLACE VIEW public.device_definitions AS
 SELECT d.id AS device_id,
    d.name AS device_name,
    d.description AS device_description,
    d.ext_id AS device_ext_id,
    d.location AS device_location,
    jsonb_agg(
        CASE
            WHEN (d.ext_id IS NULL) THEN ds.definition
            ELSE (ds.definition || jsonb_build_object('properties', (COALESCE((ds.definition -> 'properties'::text), '{}'::jsonb) || jsonb_build_object('reference', d.ext_id))))
        END ORDER BY ds.name) AS definitions
   FROM ((public.devices d
     JOIN public.device_datastreams dd ON ((d.id = dd.device_id)))
     JOIN public.datastreams ds ON ((ds.id = dd.datastream_id)))
  GROUP BY d.id;


--
-- TOC entry 3306 (class 2606 OID 31382)
-- Name: device_datastreams device_datastreams_datastream_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.device_datastreams
    ADD CONSTRAINT device_datastreams_datastream_fk FOREIGN KEY (datastream_id) REFERENCES public.datastreams(id) ON DELETE CASCADE;


--
-- TOC entry 3307 (class 2606 OID 31387)
-- Name: device_datastreams device_datastreams_device_fk; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.device_datastreams
    ADD CONSTRAINT device_datastreams_device_fk FOREIGN KEY (device_id) REFERENCES public.devices(id) ON DELETE CASCADE;
